defmodule Indexer.Fetcher.OnDemand.TokenBalance do
  @moduledoc """
  Ensures that we have a reasonably up to date address tokens balance.

  """

  use Indexer.Fetcher

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Hash
  alias Explorer.Token.BalanceReader
  alias Explorer.Utility.RateLimiter
  alias Indexer.BufferedTask
  alias Timex.Duration

  require Logger

  @behaviour BufferedTask

  @spec trigger_fetch(String.t() | nil, Hash.Address.t()) :: :ok
  def trigger_fetch(caller \\ nil, address_hash) do
    if not __MODULE__.Supervisor.disabled?() and RateLimiter.check_rate(caller, :on_demand) == :allow do
      __MODULE__.AddressQueue.enqueue(address_hash)
    end
  end

  @spec trigger_historic_fetch(
          String.t() | nil,
          Hash.t(),
          Hash.t(),
          String.t(),
          Decimal.t() | nil,
          non_neg_integer()
        ) :: :ok
  def trigger_historic_fetch(caller \\ nil, address_hash, contract_address_hash, token_type, token_id, block_number) do
    if not __MODULE__.Supervisor.disabled?() and RateLimiter.check_rate(caller, :on_demand) == :allow do
      BufferedTask.buffer(
        __MODULE__,
        [{:historic_fetch, {address_hash, contract_address_hash, token_type, token_id, block_number}}],
        false
      )
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, %{})

    children = [
      {Task.Supervisor, name: __MODULE__.AddressQueue.TaskSupervisor},
      __MODULE__.AddressQueue,
      {BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}
    ]

    %{
      id: __MODULE__,
      start:
        {Supervisor, :start_link,
         [children, [strategy: :one_for_one, name: Module.concat(__MODULE__, InternalSupervisor)]]},
      type: :supervisor
    }
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(entries, _) do
    entries_by_type = Enum.group_by(entries, &elem(&1, 0), &elem(&1, 1))

    latest_block_number = latest_block_number()

    fetch_data = prepare_fetch_requests(entries_by_type[:fetch], latest_block_number)

    {historic_fetch_ft_requests, historic_fetch_nft_requests} =
      prepare_historic_fetch_requests(entries_by_type[:historic_fetch])

    all_responses =
      BalanceReader.get_balances_of_all(
        fetch_data.ft_balances ++ historic_fetch_ft_requests,
        fetch_data.nft_balances ++ historic_fetch_nft_requests
      )

    {fetch_ft_responses, other_responses} = Enum.split(all_responses, Enum.count(fetch_data.ft_balances))
    {historic_fetch_ft_responses, nft_responses} = Enum.split(other_responses, Enum.count(historic_fetch_ft_requests))
    {fetch_nft_responses, historic_fetch_nft_responses} = Enum.split(nft_responses, Enum.count(fetch_data.nft_balances))

    (fetch_ft_responses ++ fetch_nft_responses)
    |> Enum.zip(fetch_data.ft_balances ++ fetch_data.nft_balances)
    |> process_fetch_responses(fetch_data.tokens, fetch_data.balances_map, latest_block_number)

    (historic_fetch_ft_responses ++ historic_fetch_nft_responses)
    |> Enum.zip(historic_fetch_ft_requests ++ historic_fetch_nft_requests)
    |> process_historic_fetch_responses()

    :ok
  end

  defp prepare_fetch_requests(nil, _latest_block_number),
    do: %{nft_balances: [], ft_balances: [], tokens: %{}, balances_map: %{}}

  defp prepare_fetch_requests(entries, latest_block_number) do
    initial_acc = %{nft_balances: [], ft_balances: [], tokens: %{}, balances_map: %{}}

    Enum.reduce(entries, initial_acc, fn ctb, acc ->
      updated_tokens =
        Map.put_new(
          acc[:tokens],
          ctb.token.contract_address_hash.bytes,
          ctb.token
        )

      prepared_ctb =
        ctb
        |> Map.drop([:token, :stale_value])
        |> Map.put(:block_number, latest_block_number)
        |> Map.put(:token_id, ctb.token_id && Decimal.to_integer(ctb.token_id))
        |> Map.put(:token_contract_address_hash, to_string(ctb.token_contract_address_hash))
        |> Map.put(:address_hash, to_string(ctb.address_hash))

      result =
        if ctb.token_type == "ERC-1155" do
          Map.put(acc, :nft_balances, [prepared_ctb | acc[:nft_balances]])
        else
          Map.put(acc, :ft_balances, [prepared_ctb | acc[:ft_balances]])
        end

      updated_balances_map =
        Map.put(
          acc[:balances_map],
          ctb_to_key(ctb),
          ctb.stale_value
        )

      result
      |> Map.put(:tokens, updated_tokens)
      |> Map.put(:balances_map, updated_balances_map)
    end)
  end

  def prepare_batch_fetch_entries_for_buffer(address_hashes, latest_block_number) do
    case stale_balance_window(latest_block_number) do
      {:error, _} ->
        []

      stale_balance_window ->
        address_hashes
        |> Enum.uniq()
        |> Chain.fetch_last_token_balances_include_unfetched()
        |> delete_invalid_balances()
        |> Enum.filter(fn ctb -> ctb.block_number < stale_balance_window end)
        |> prepare_ctb_params_for_buffer()
    end
  end

  defp prepare_ctb_params_for_buffer(current_token_balances) do
    Enum.map(current_token_balances, fn %{token_id: token_id} = stale_current_token_balance ->
      {:fetch,
       %{
         token_contract_address_hash: stale_current_token_balance.token_contract_address_hash,
         address_hash: stale_current_token_balance.address_hash,
         block_number: nil,
         token_id: token_id,
         token_type: stale_current_token_balance.token_type,
         token: stale_current_token_balance.token,
         stale_value: stale_current_token_balance.value
       }}
    end)
  end

  defp prepare_historic_fetch_requests(nil), do: {[], []}

  defp prepare_historic_fetch_requests(params) do
    Enum.reduce(params, {[], []}, fn {address_hash, contract_address_hash, token_type, token_id, block_number},
                                     {regular_acc, erc_1155_acc} ->
      request = %{
        token_contract_address_hash: to_string(contract_address_hash),
        address_hash: to_string(address_hash),
        block_number: block_number,
        token_type: token_type,
        token_id: token_id && Decimal.to_integer(token_id)
      }

      case {token_type, token_id} do
        {"ERC-404", nil} -> {[request | regular_acc], erc_1155_acc}
        {"ERC-404", _token_id} -> {regular_acc, [request | erc_1155_acc]}
        {"ERC-1155", _token_id} -> {regular_acc, [request | erc_1155_acc]}
        {_type, _token_id} -> {[request | regular_acc], erc_1155_acc}
      end
    end)
  end

  defp process_fetch_responses(responses, tokens, balances_map, block_number) do
    filtered_current_token_balances_update_params =
      responses
      |> Enum.map(&prepare_updated_balance(&1, block_number))
      |> Enum.reject(&is_nil/1)

    if not Enum.empty?(filtered_current_token_balances_update_params) do
      {:ok,
       %{
         address_current_token_balances: imported_ctbs
       }} =
        Chain.import(%{
          address_current_token_balances: %{
            params: filtered_current_token_balances_update_params
          },
          broadcast: false
        })

      imported_ctbs
      |> filter_imported_ctbs(balances_map)
      |> Enum.group_by(& &1.address_hash)
      |> Enum.each(fn {address_hash, ctbs} ->
        Publisher.broadcast(
          %{
            address_current_token_balances: %{
              address_hash: to_string(address_hash),
              address_current_token_balances:
                Enum.map(ctbs, fn %CurrentTokenBalance{} = ctb ->
                  %CurrentTokenBalance{ctb | token: tokens[ctb.token_contract_address_hash.bytes]}
                end)
            }
          },
          :on_demand
        )
      end)
    end
  end

  defp process_historic_fetch_responses([]), do: :ok

  defp process_historic_fetch_responses(responses) do
    import_params =
      Enum.reduce(responses, [], fn
        {{:ok, balance}, request}, acc ->
          params = %{
            address_hash: request.address_hash,
            token_contract_address_hash: request.token_contract_address_hash,
            token_type: request.token_type,
            token_id: request.token_id,
            block_number: request.block_number,
            value: Decimal.new(balance),
            value_fetched_at: DateTime.utc_now()
          }

          [params | acc]

        {{:error, error}, request}, acc ->
          Logger.error("Error while fetching token balances: #{inspect(error)}, request: #{inspect(request)}")
          acc
      end)

    Chain.import(%{address_token_balances: %{params: import_params}, broadcast: :on_demand})
  end

  defp delete_invalid_balances(current_token_balances) do
    {invalid_balances, valid_balances} = Enum.split_with(current_token_balances, &is_nil(&1.token_type))
    Enum.each(invalid_balances, &Repo.delete/1)
    valid_balances
  end

  defp filter_imported_ctbs(imported_ctbs, balances_map) do
    Enum.filter(imported_ctbs, fn ctb ->
      case Map.fetch(balances_map, ctb_to_key(ctb)) do
        {:ok, nil} ->
          true

        {:ok, balance} ->
          Decimal.compare(balance, ctb.value) != :eq

        :error ->
          Logger.error("Imported unknown balance #{inspect(ctb)}")
          true
      end
    end)
  end

  defp ctb_to_key(ctb) do
    {ctb.address_hash.bytes, ctb.token_contract_address_hash.bytes, ctb.token_type,
     ctb.token_id && Decimal.to_integer(ctb.token_id)}
  end

  defp prepare_updated_balance({{:ok, updated_balance}, stale_current_token_balance}, block_number) do
    %{}
    |> Map.put(:address_hash, stale_current_token_balance.address_hash)
    |> Map.put(:token_contract_address_hash, stale_current_token_balance.token_contract_address_hash)
    |> Map.put(:token_type, stale_current_token_balance.token_type)
    |> Map.put(:token_id, stale_current_token_balance.token_id)
    |> Map.put(:block_number, block_number)
    |> Map.put(:value, Decimal.new(updated_balance))
    |> Map.put(:value_fetched_at, DateTime.utc_now())
  end

  defp prepare_updated_balance({{:error, error}, ctb}, block_number) do
    error_message =
      if ctb.token_id do
        "Error on updating current token #{to_string(ctb.token_contract_address_hash)} balance for address #{to_string(ctb.address_hash)} and token id #{to_string(ctb.token_id)} at block number #{block_number}: "
      else
        "Error on updating current token #{to_string(ctb.token_contract_address_hash)} balance for address #{to_string(ctb.address_hash)} at block number #{block_number}: "
      end

    Logger.warning(fn ->
      [
        error_message,
        inspect(error)
      ]
    end)

    nil
  end

  def latest_block_number do
    BlockNumber.get_max()
  end

  defp stale_balance_window(block_number) do
    case AverageBlockTime.average_block_time() do
      {:error, :disabled} ->
        fallback_threshold_in_blocks = Application.get_env(:indexer, __MODULE__)[:fallback_threshold_in_blocks]
        block_number - fallback_threshold_in_blocks

      duration ->
        average_block_time =
          duration
          |> Duration.to_milliseconds()
          |> round()

        if average_block_time == 0 do
          {:error, :empty_database}
        else
          threshold = Application.get_env(:indexer, __MODULE__)[:threshold]
          block_number - div(threshold, average_block_time)
        end
    end
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(3),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency],
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size],
      task_supervisor: Indexer.Fetcher.OnDemand.TokenBalance.TaskSupervisor,
      metadata: [fetcher: :token_balance_on_demand]
    ]
  end
end

defmodule Indexer.Fetcher.OnDemand.TokenBalance.AddressQueue do
  @moduledoc """
  Buffers incoming address hashes from `trigger_fetch/2` and flushes them in batches.
  Each batch fetches token balances for all addresses in a single DB query,
  then forwards the results to the main TokenBalance BufferedTask.
  """

  @behaviour Indexer.BufferedTask

  alias Explorer.Chain.Hash
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.OnDemand.TokenBalance

  @spec enqueue(Hash.Address.t()) :: :ok
  def enqueue(address_hash) do
    BufferedTask.buffer(__MODULE__, [address_hash], false)
  end

  def child_spec(_opts \\ []) do
    init_opts = [
      flush_interval: Application.get_env(:indexer, TokenBalance)[:address_queue_flush_interval],
      max_concurrency: 1,
      max_batch_size: Application.get_env(:indexer, TokenBalance)[:address_queue_batch_size],
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :token_balance_on_demand_address_queue],
      state: %{}
    ]

    Supervisor.child_spec({BufferedTask, [{__MODULE__, init_opts}, [name: __MODULE__]]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _, _), do: initial

  @impl BufferedTask
  def run(address_hashes, _) do
    latest_block_number = TokenBalance.latest_block_number()

    fetch_data = TokenBalance.prepare_batch_fetch_entries_for_buffer(address_hashes, latest_block_number)

    unless Enum.empty?(fetch_data) do
      BufferedTask.buffer(TokenBalance, fetch_data, false)
    end

    :ok
  end
end
