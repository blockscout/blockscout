defmodule Indexer.Block.Realtime.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward using a WebSocket.
  """

  use GenServer
  use Spandex.Decorators

  require Indexer.Tracer
  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  import Indexer.Block.Fetcher,
    only: [
      async_import_block_rewards: 1,
      async_import_created_contract_codes: 1,
      async_import_internal_transactions: 2,
      async_import_replaced_transactions: 1,
      async_import_tokens: 1,
      async_import_token_balances: 1,
      async_import_token_instances: 1,
      async_import_uncles: 1,
      fetch_and_import_range: 2
    ]

  alias Ecto.Changeset
  alias EthereumJSONRPC.{FetchedBalances, Subscription}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Counters.AverageBlockTime
  alias Indexer.{Block, Tracer}
  alias Indexer.Block.Realtime.TaskSupervisor
  alias Indexer.Transform.Addresses
  alias Timex.Duration

  @behaviour Block.Fetcher

  @minimum_safe_polling_period :timer.seconds(10)

  @enforce_keys ~w(block_fetcher)a
  defstruct ~w(block_fetcher subscription previous_number max_number_seen timer)a

  @type t :: %__MODULE__{
          block_fetcher: %Block.Fetcher{
            broadcast: term(),
            callback_module: __MODULE__,
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments(),
            receipts_batch_size: pos_integer(),
            receipts_concurrency: pos_integer()
          },
          subscription: Subscription.t(),
          previous_number: pos_integer() | nil,
          max_number_seen: pos_integer() | nil
        }

  def start_link([arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(%{block_fetcher: %Block.Fetcher{} = block_fetcher, subscribe_named_arguments: subscribe_named_arguments}) do
    Logger.metadata(fetcher: :block_realtime)

    {:ok, %__MODULE__{block_fetcher: %Block.Fetcher{block_fetcher | broadcast: :realtime, callback_module: __MODULE__}},
     {:continue, {:init, subscribe_named_arguments}}}
  end

  @impl GenServer
  def handle_continue({:init, subscribe_named_arguments}, %__MODULE__{subscription: nil} = state) do
    timer = schedule_polling()
    {:noreply, %__MODULE__{state | timer: timer} |> subscribe_to_new_heads(subscribe_named_arguments)}
  end

  @impl GenServer
  def handle_info(
        {subscription, {:ok, %{"number" => quantity}}},
        %__MODULE__{
          block_fetcher: %Block.Fetcher{} = block_fetcher,
          subscription: %Subscription{} = subscription,
          previous_number: previous_number,
          max_number_seen: max_number_seen,
          timer: timer
        } = state
      )
      when is_binary(quantity) do
    number = quantity_to_integer(quantity)
    # Subscriptions don't support getting all the blocks and transactions data,
    # so we need to go back and get the full block
    {new_previous_number, new_max_number} =
      case start_fetch_and_import(number, block_fetcher, previous_number, max_number_seen) do
        # The number may have not been inserted if it was part of a small skip
        :skip ->
          Logger.debug(["#{inspect(number)} was skipped"])
          {previous_number, max_number_seen}

        _ ->
          {number, new_max_number(number, max_number_seen)}
      end

    Process.cancel_timer(timer)
    new_timer = schedule_polling()

    {:noreply,
     %{
       state
       | previous_number: new_previous_number,
         max_number_seen: new_max_number,
         timer: new_timer
     }}
  end

  @impl GenServer
  def handle_info(
        :poll_latest_block_number,
        %__MODULE__{
          block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher,
          previous_number: previous_number,
          max_number_seen: max_number_seen
        } = state
      ) do
    {number, new_max_number} =
      case EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) do
        {:ok, number} when is_nil(max_number_seen) or number > max_number_seen ->
          # in case of polling the realtime fetcher should take care of all the
          # blocks in the skipping window, because the cathup fetcher wont
          max_skipping_distance = Application.get_env(:indexer, :max_skipping_distance)

          last_catchup_number = max(0, 10 - max_skipping_distance - 1)
          starting_number = max(previous_number, last_catchup_number) || last_catchup_number

          start_fetch_and_import(number, block_fetcher, starting_number, nil)

          {max_number_seen, number}

        _ ->
          {previous_number, max_number_seen}
      end

    timer = schedule_polling()

    {:noreply,
     %{
       state
       | previous_number: number,
         max_number_seen: new_max_number,
         timer: timer
     }}
  end

  defp subscribe_to_new_heads(%__MODULE__{subscription: nil} = state, subscribe_named_arguments)
       when is_list(subscribe_named_arguments) do
    case EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments) do
      {:ok, subscription} ->
        %__MODULE__{state | subscription: subscription}

      {:error, reason} ->
        Logger.debug(fn -> ["Could not connect to websocket: #{inspect(reason)}. Continuing with polling."] end)
        state
    end
  end

  defp subscribe_to_new_heads(state, _), do: state

  defp new_max_number(number, nil), do: number

  defp new_max_number(number, max_number_seen), do: max(number, max_number_seen)

  defp schedule_polling do
    polling_period =
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} -> 2_000
        block_time -> round(Duration.to_milliseconds(block_time) * 2)
      end

    safe_polling_period = max(polling_period, @minimum_safe_polling_period)

    Process.send_after(self(), :poll_latest_block_number, safe_polling_period)
  end

  @import_options ~w(address_hash_to_fetched_balance_block_number)a

  @impl Block.Fetcher
  def import(
        %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher,
        %{
          address_coin_balances: %{params: address_coin_balances_params},
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number,
          addresses: %{params: addresses_params},
          block_rewards: block_rewards
        } = options
      ) do
    with {:balances, {:ok, %{addresses_params: balances_addresses_params, balances_params: balances_params}}} <-
           {:balances,
            balances(block_fetcher, %{
              address_hash_to_block_number: address_hash_to_block_number,
              addresses_params: addresses_params,
              balances_params: address_coin_balances_params
            })},
         {block_reward_errors, chain_import_block_rewards} = Map.pop(block_rewards, :errors),
         chain_import_options =
           options
           |> Map.drop(@import_options)
           |> put_in([:addresses, :params], balances_addresses_params)
           |> put_in([:blocks, :params, Access.all(), :consensus], true)
           |> put_in([:block_rewards], chain_import_block_rewards)
           |> put_in([Access.key(:address_coin_balances, %{}), :params], balances_params),
         {:import, {:ok, imported} = ok} <- {:import, Chain.import(chain_import_options)} do
      async_import_remaining_block_data(
        imported,
        %{block_rewards: %{errors: block_reward_errors}},
        json_rpc_named_arguments
      )

      Accounts.drop(imported[:addresses])

      ok
    end
  end

  def import(_, _) do
    Logger.warn("Empty parameters were provided for realtime fetcher")

    {:ok, []}
  end

  defp start_fetch_and_import(number, block_fetcher, previous_number, max_number_seen) do
    fetching_action = determine_fetching_action(number, previous_number, max_number_seen)

    if fetching_action != :skip do
      for block_number_to_fetch <- fetching_action do
        args = [block_number_to_fetch, block_fetcher, reorg?(number, max_number_seen)]
        Task.Supervisor.start_child(TaskSupervisor, __MODULE__, :fetch_and_import_block, args)
      end
    end

    fetching_action
  end

  def determine_fetching_action(number, previous_number, max_number_seen) do
    cond do
      reorg?(number, max_number_seen) ->
        [number]

      can_be_skipped?(number, max_number_seen) ->
        :skip

      is_nil(previous_number) ->
        [number]

      true ->
        (previous_number + 1)..number
    end
  end

  defp reorg?(number, max_number_seen) when is_integer(max_number_seen) and number <= max_number_seen do
    true
  end

  defp reorg?(_, _), do: false

  defp can_be_skipped?(number, max_number_seen) when is_integer(max_number_seen) and number > max_number_seen + 1 do
    max_skipping_distance = Application.get_env(:indexer, :max_skipping_distance)

    max_skipping_distance > 1 and number <= max_number_seen + max_skipping_distance
  end

  defp can_be_skipped?(_, _), do: false

  @reorg_delay 5_000

  @decorate trace(name: "fetch", resource: "Indexer.Block.Realtime.Fetcher.fetch_and_import_block/3", tracer: Tracer)
  def fetch_and_import_block(block_number_to_fetch, block_fetcher, reorg?, retry \\ 3) do
    Indexer.Logger.metadata(
      fn ->
        if reorg? do
          # give previous fetch attempt (for same block number) a chance to finish
          # before fetching again, to reduce block consensus mistakes
          :timer.sleep(@reorg_delay)
        end

        do_fetch_and_import_block(block_number_to_fetch, block_fetcher, retry)
      end,
      fetcher: :block_realtime,
      block_number: block_number_to_fetch
    )
  end

  @decorate span(tracer: Tracer)
  defp do_fetch_and_import_block(block_number_to_fetch, block_fetcher, retry) do
    case fetch_and_import_range(block_fetcher, block_number_to_fetch..block_number_to_fetch) do
      {:ok, %{inserted: _, errors: []}} ->
        Logger.debug("Fetched and imported.")

      {:ok, %{inserted: _, errors: [_ | _] = errors}} ->
        Logger.error(fn ->
          [
            "failed to fetch block: ",
            inspect(errors),
            ".  Block will be retried by catchup indexer."
          ]
        end)

      {:error, {:import = step, [%Changeset{} | _] = changesets}} ->
        params = %{
          changesets: changesets,
          block_number_to_fetch: block_number_to_fetch,
          block_fetcher: block_fetcher,
          retry: retry
        }

        if retry_fetch_and_import_block(params) == :ignore do
          Logger.error(
            fn ->
              [
                "failed to validate for block ",
                to_string(block_number_to_fetch),
                ": ",
                inspect(changesets),
                ".  Block will be retried by catchup indexer."
              ]
            end,
            step: step
          )
        end

      {:error, {:import = step, reason}} ->
        Logger.error(fn -> inspect(reason) end, step: step)

      {:error, {step, reason}} ->
        Logger.error(
          fn ->
            [
              "failed to fetch: ",
              inspect(reason),
              ".  Block will be retried by catchup indexer."
            ]
          end,
          step: step
        )

      {:error, {step, failed_value, _changes_so_far}} ->
        Logger.error(
          fn ->
            [
              "failed to insert: ",
              inspect(failed_value),
              ".  Block will be retried by catchup indexer."
            ]
          end,
          step: step
        )
    end
  end

  defp retry_fetch_and_import_block(%{retry: retry}) when retry < 1, do: :ignore

  defp retry_fetch_and_import_block(%{changesets: changesets} = params) do
    if unknown_block_number_error?(changesets) do
      # Wait half a second to give Parity time to sync.
      :timer.sleep(500)

      number = params.block_number_to_fetch
      fetcher = params.block_fetcher
      updated_retry = params.retry - 1

      do_fetch_and_import_block(number, fetcher, updated_retry)
    else
      :ignore
    end
  end

  defp unknown_block_number_error?(changesets) do
    Enum.any?(changesets, &(Map.get(&1, :message) == "Unknown block number"))
  end

  defp async_import_remaining_block_data(
         imported,
         %{block_rewards: %{errors: block_reward_errors}},
         json_rpc_named_arguments
       ) do
    async_import_block_rewards(block_reward_errors)
    async_import_created_contract_codes(imported)
    async_import_internal_transactions(imported, Keyword.get(json_rpc_named_arguments, :variant))
    async_import_tokens(imported)
    async_import_token_balances(imported)
    async_import_token_instances(imported)
    async_import_uncles(imported)
    async_import_replaced_transactions(imported)
  end

  defp balances(
         %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments},
         %{addresses_params: addresses_params} = options
       ) do
    case options
         |> fetch_balances_params_list()
         |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments) do
      {:ok, %FetchedBalances{params_list: params_list, errors: []}} ->
        merged_addresses_params =
          %{address_coin_balances: params_list}
          |> Addresses.extract_addresses()
          |> Kernel.++(addresses_params)
          |> Addresses.merge_addresses()

        value_fetched_at = DateTime.utc_now()

        importable_balances_params = Enum.map(params_list, &Map.put(&1, :value_fetched_at, value_fetched_at))

        {:ok, %{addresses_params: merged_addresses_params, balances_params: importable_balances_params}}

      {:error, _} = error ->
        error

      {:ok, %FetchedBalances{errors: errors}} ->
        {:error, errors}
    end
  end

  defp fetch_balances_params_list(%{
         addresses_params: addresses_params,
         address_hash_to_block_number: address_hash_to_block_number,
         balances_params: balances_params
       }) do
    addresses_params
    |> addresses_params_to_fetched_balances_params_set(%{address_hash_to_block_number: address_hash_to_block_number})
    |> MapSet.union(balances_params_to_fetch_balances_params_set(balances_params))
    # stable order for easier moxing
    |> Enum.sort_by(fn %{hash_data: hash_data, block_quantity: block_quantity} -> {hash_data, block_quantity} end)
  end

  defp addresses_params_to_fetched_balances_params_set(addresses_params, %{
         address_hash_to_block_number: address_hash_to_block_number
       }) do
    Enum.into(addresses_params, MapSet.new(), fn %{hash: address_hash} = address_params when is_binary(address_hash) ->
      block_number =
        case address_params do
          %{fetched_coin_balance_block_number: block_number} when is_integer(block_number) ->
            block_number

          _ ->
            Map.fetch!(address_hash_to_block_number, address_hash)
        end

      %{hash_data: address_hash, block_quantity: integer_to_quantity(block_number)}
    end)
  end

  defp balances_params_to_fetch_balances_params_set(balances_params) do
    Enum.into(balances_params, MapSet.new(), fn %{address_hash: address_hash, block_number: block_number} ->
      %{hash_data: address_hash, block_quantity: integer_to_quantity(block_number)}
    end)
  end
end
