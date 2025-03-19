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
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Token.BalanceReader
  alias Indexer.BufferedTask
  alias Timex.Duration

  require Logger

  @behaviour BufferedTask

  @max_batch_size 500
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.OnDemand.TokenBalance.TaskSupervisor,
    metadata: [fetcher: :token_balance_on_demand]
  ]

  @spec trigger_fetch(Hash.Address.t()) :: :ok
  def trigger_fetch(address_hash) do
    unless __MODULE__.Supervisor.disabled?() do
      BufferedTask.buffer(__MODULE__, [{:fetch, address_hash}], false)
    end
  end

  @spec trigger_historic_fetch(
          Hash.t(),
          Hash.t(),
          String.t(),
          Decimal.t() | nil,
          non_neg_integer()
        ) :: :ok
  def trigger_historic_fetch(address_hash, contract_address_hash, token_type, token_id, block_number) do
    unless __MODULE__.Supervisor.disabled?() do
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
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, %{})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(entries, _) do
    {fetch_params, historic_fetch_params} =
      Enum.reduce(entries, {[], []}, fn
        {:fetch, address_hash}, {fetch_acc, historic_acc} ->
          {[address_hash | fetch_acc], historic_acc}

        {:historic_fetch, params}, {fetch_acc, historic_acc} ->
          {fetch_acc, [params | historic_acc]}
      end)

    do_trigger_fetch(fetch_params)
    do_trigger_historic_fetch(historic_fetch_params)

    :ok
  end

  defp do_trigger_fetch([]), do: :ok

  defp do_trigger_fetch(address_hashes) do
    latest_block_number = latest_block_number()

    case stale_balance_window(latest_block_number) do
      {:error, _} ->
        :current

      stale_balance_window ->
        stale_current_token_balances =
          address_hashes
          |> Chain.fetch_last_token_balances_include_unfetched()
          |> delete_invalid_balances()
          |> Enum.filter(fn current_token_balance -> current_token_balance.block_number < stale_balance_window end)

        if Enum.empty?(stale_current_token_balances) do
          :current
        else
          fetch_and_update(latest_block_number, stale_current_token_balances)
        end
    end
  end

  defp delete_invalid_balances(current_token_balances) do
    {invalid_balances, valid_balances} = Enum.split_with(current_token_balances, &is_nil(&1.token_type))
    Enum.each(invalid_balances, &Repo.delete/1)
    valid_balances
  end

  defp fetch_and_update(block_number, stale_current_token_balances) do
    %{
      erc_1155: erc_1155_ctbs,
      other: other_ctbs,
      tokens: tokens,
      balances_map: balances_map
    } =
      stale_current_token_balances
      |> Enum.reduce(%{erc_1155: [], other: [], tokens: %{}, balances_map: %{}}, fn %{
                                                                                      token_id: token_id
                                                                                    } = stale_current_token_balance,
                                                                                    acc ->
        prepared_ctb = %{
          token_contract_address_hash:
            ExplorerHelper.add_0x_prefix(stale_current_token_balance.token.contract_address_hash),
          address_hash: ExplorerHelper.add_0x_prefix(stale_current_token_balance.address_hash),
          block_number: block_number,
          token_id: token_id && Decimal.to_integer(token_id),
          token_type: stale_current_token_balance.token_type
        }

        updated_tokens =
          Map.put_new(
            acc[:tokens],
            stale_current_token_balance.token.contract_address_hash.bytes,
            stale_current_token_balance.token
          )

        result =
          if stale_current_token_balance.token_type == "ERC-1155" do
            Map.put(acc, :erc_1155, [prepared_ctb | acc[:erc_1155]])
          else
            Map.put(acc, :other, [prepared_ctb | acc[:other]])
          end

        updated_balances_map =
          Map.put(
            acc[:balances_map],
            ctb_to_key(stale_current_token_balance),
            stale_current_token_balance.value
          )

        result
        |> Map.put(:tokens, updated_tokens)
        |> Map.put(:balances_map, updated_balances_map)
      end)

    updated_erc_1155_ctbs =
      if Enum.empty?(erc_1155_ctbs) do
        []
      else
        erc_1155_ctbs
        |> BalanceReader.get_balances_of_erc_1155()
        |> Enum.zip(erc_1155_ctbs)
        |> Enum.map(&prepare_updated_balance(&1, block_number))
      end

    updated_other_ctbs =
      if Enum.empty?(other_ctbs) do
        []
      else
        other_ctbs
        |> BalanceReader.get_balances_of()
        |> Enum.zip(other_ctbs)
        |> Enum.map(&prepare_updated_balance(&1, block_number))
      end

    filtered_current_token_balances_update_params =
      (updated_erc_1155_ctbs ++ updated_other_ctbs) |> Enum.filter(&(!is_nil(&1)))

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
                Enum.map(ctbs, fn ctb ->
                  %CurrentTokenBalance{ctb | token: tokens[ctb.token_contract_address_hash.bytes]}
                end)
            }
          },
          :on_demand
        )
      end)
    end
  end

  defp filter_imported_ctbs(imported_ctbs, balances_map) do
    Enum.filter(imported_ctbs, fn ctb ->
      if balance = balances_map[ctb_to_key(ctb)] do
        Decimal.compare(balance, ctb.value) != :eq
      else
        Logger.error("Imported unknown balance")
        true
      end
    end)
  end

  defp ctb_to_key(ctb) do
    {ctb.token_contract_address_hash.bytes, ctb.token_type, ctb.token_id && Decimal.to_integer(ctb.token_id)}
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

  defp do_trigger_historic_fetch([]), do: :ok

  defp do_trigger_historic_fetch(params) do
    {regular_requests, erc_1155_requests} =
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

    regular_balances_response =
      regular_requests
      |> BalanceReader.get_balances_of()
      |> Enum.zip(regular_requests)

    erc_1155_balances_response =
      erc_1155_requests
      |> BalanceReader.get_balances_of_erc_1155()
      |> Enum.zip(erc_1155_requests)

    import_params =
      Enum.reduce(regular_balances_response ++ erc_1155_balances_response, [], fn
        {{:ok, balance}, request}, acc ->
          params = %{
            address_hash: request.address_hash,
            token_contract_address_hash: request.contract_address_hash,
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

  defp latest_block_number do
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
end
