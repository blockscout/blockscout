# SPDX-License-Identifier: LicenseRef-Blockscout
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
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Token.BalanceReader
  alias Explorer.Utility.RateLimiter
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.TokenBalance.Helper, as: TokenBalanceHelper
  alias Timex.Duration

  require Logger

  @behaviour BufferedTask

  @current_fetch_timeout 1_000

  @spec trigger_fetch(String.t() | nil, Hash.Address.t()) :: :ok
  def trigger_fetch(caller \\ nil, address_hash) do
    if not __MODULE__.Supervisor.disabled?() and RateLimiter.check_rate(caller, :on_demand) == :allow do
      __MODULE__.AddressQueue.enqueue(address_hash)
    end
  end

  @doc """
  Schedules a fetch of the current fungible token balances held by `address_hashes`.

  The balances are read at the latest block and imported as current token
  balances. A failed read is imported as an unfetched balance with the next
  `retries_count` and a `refetch_after` backoff, so callers can skip it until
  then. The function does not check what is already indexed: the caller passes
  only the addresses whose balance of `token` is missing, or unfetched and due
  for a retry. Used to backfill burn address balances of ERC-20 and ERC-8056
  tokens indexed before those were tracked.

  Best effort: it never raises and waits at most #{@current_fetch_timeout} ms
  for the fetcher. A busy or restarting fetcher or rate limiter only leaves the
  work to a later call.

  ## Parameters
  - `caller`: identifier for the `:on_demand_burn_address_balances` rate limit,
    such as the client IP, or `nil` for no limit. This budget is separate from
    `:on_demand`, so the backfill does not use up other on-demand refreshes of
    the same request.
  - `addresses`: `{address_hash, retries_count}` pairs, where `retries_count` is
    the number of failed fetches so far, `0` for a missing balance.
  - `token`: the fungible token, with `contract_address_hash` and `type` set.

  ## Returns
  - `:ok` in all cases.
  """
  @spec trigger_current_fetch(String.t() | nil, [{Hash.Address.t(), non_neg_integer()}], Token.t()) :: :ok
  def trigger_current_fetch(caller \\ nil, addresses, token)

  def trigger_current_fetch(_caller, [], %Token{}), do: :ok

  def trigger_current_fetch(caller, addresses, %Token{} = token) when is_list(addresses) do
    if not __MODULE__.Supervisor.disabled?() do
      try do
        if RateLimiter.check_rate(caller, :on_demand_burn_address_balances) == :allow do
          BufferedTask.buffer(__MODULE__, current_fetch_entries(addresses, token), false, @current_fetch_timeout)
        end
      rescue
        error ->
          Logger.debug(fn -> "On-demand current token balance fetch not scheduled: #{inspect(error)}" end)
      catch
        :exit, reason ->
          Logger.debug(fn -> "On-demand current token balance fetch not scheduled: #{inspect(reason)}" end)
      end
    end

    :ok
  end

  # `retries_count` marks the entry as a backfill: a failed read is imported with
  # retry metadata, unlike stale balance refreshes, whose failures are only logged
  defp current_fetch_entries(addresses, token) do
    Enum.map(addresses, fn {address_hash, retries_count} ->
      {:fetch,
       %{
         token_contract_address_hash: token.contract_address_hash,
         address_hash: address_hash,
         block_number: nil,
         token_id: nil,
         token_type: token.type,
         token: token,
         stale_value: nil,
         retries_count: retries_count
       }}
    end)
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

    fetch_data =
      prepare_fetch_requests(
        entries_by_type[:fetch] && dedup_fetch_entries(entries_by_type[:fetch]),
        latest_block_number
      )

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

  # The same balance can be requested several times before the first request is
  # imported, for instance by concurrent token page views, so it is read only
  # once per batch. The last entry is kept, so its `stale_value` stays the
  # baseline that suppresses broadcasts of unchanged balances, as it was in
  # `balances_map` before deduplication. When any entry of the balance is a
  # backfill (it has a `retries_count`, see `trigger_current_fetch/3`), the kept
  # entry carries the highest `retries_count`, so a failed read still records
  # its backoff.
  defp dedup_fetch_entries(entries) do
    entries
    |> Enum.group_by(&{&1.address_hash, &1.token_contract_address_hash, &1.token_id})
    |> Enum.map(fn {_key, same_balance_entries} -> merge_same_balance_entries(same_balance_entries) end)
  end

  defp merge_same_balance_entries(same_balance_entries) do
    last_entry = List.last(same_balance_entries)

    case for(%{retries_count: retries_count} <- same_balance_entries, do: retries_count) do
      [] -> last_entry
      retries_counts -> Map.put(last_entry, :retries_count, Enum.max(retries_counts))
    end
  end

  defp prepare_fetch_requests(nil, _latest_block_number),
    do: %{nft_balances: [], ft_balances: [], tokens: %{}, balances_map: %{}}

  defp prepare_fetch_requests(entries, latest_block_number) do
    initial_acc = %{nft_balances: [], ft_balances: [], tokens: %{}, balances_map: %{}}

    Enum.reduce(entries, initial_acc, fn ctb, acc ->
      updated_tokens =
        Map.put_new(
          acc[:tokens],
          ctb.token_contract_address_hash.bytes,
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
        |> Chain.fetch_last_token_balances_include_unfetched(stale_balance_window)
        |> delete_invalid_balances()
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
    {fetched_balance_params, failed_backfill_params} =
      responses
      |> Enum.map(&prepare_updated_balance(&1, block_number))
      |> Enum.reject(&is_nil/1)
      |> Enum.split_with(&(not is_nil(&1.value)))

    # Not imported like fetched balances: a newer-block import would keep the
    # stored value of a balance fetched meanwhile but mark it unfetched
    CurrentTokenBalance.record_backfill_failures(failed_backfill_params)

    filtered_current_token_balances_update_params = fetched_balance_params

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

      ctbs_with_tokens =
        imported_ctbs
        |> filter_imported_ctbs(balances_map)
        |> Enum.map(fn %CurrentTokenBalance{} = ctb ->
          %CurrentTokenBalance{ctb | token: tokens[ctb.token_contract_address_hash.bytes]}
        end)

      unless ctbs_with_tokens == [] do
        Publisher.broadcast(%{address_current_token_balances: ctbs_with_tokens}, :on_demand)
      end
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

    unless Enum.empty?(import_params) do
      {:ok,
       %{
         address_token_balances: imported_tbs
       }} = Chain.import(%{address_token_balances: %{params: import_params}, broadcast: :on_demand})

      unless imported_tbs == [] do
        Publisher.broadcast(%{address_token_balances: imported_tbs}, :on_demand)
      end
    end
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

    failed_balance_retry_params(ctb, block_number)
  end

  # A failed backfill (see `trigger_current_fetch/3`) is recorded as an unfetched
  # balance with retry metadata, so it is not requested again before
  # `refetch_after`, see `CurrentTokenBalance.record_backfill_failures/1`. A
  # failed refresh of a stale balance keeps its stored value.
  defp failed_balance_retry_params(%{retries_count: retries_count} = ctb, block_number) do
    new_retries_count = retries_count + 1

    %{
      address_hash: ctb.address_hash,
      token_contract_address_hash: ctb.token_contract_address_hash,
      token_type: ctb.token_type,
      token_id: ctb.token_id,
      block_number: block_number,
      value: nil,
      value_fetched_at: nil,
      retries_count: new_retries_count,
      refetch_after: TokenBalanceHelper.define_refetch_after(new_retries_count)
    }
  end

  defp failed_balance_retry_params(_ctb, _block_number), do: nil

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
