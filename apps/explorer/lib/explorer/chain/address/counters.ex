# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.Counters do
  @moduledoc """
    Functions related to Explorer.Chain.Address counters
  """
  use Utils.RuntimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  import Ecto.Query, only: [from: 2, limit: 2, select: 3, union_all: 2, where: 3]

  import Explorer.Chain,
    only: [select_repo: 1, wrapped_union_subquery: 1]

  alias Explorer.{Chain, PagingOptions}

  alias Explorer.Chain.Cache.Counters.AddressTabsElementsCount

  alias Explorer.Chain.{
    Address,
    Address.CurrentTokenBalance,
    Block,
    Hash,
    InternalTransaction,
    Log,
    TokenTransfer,
    Transaction,
    Withdrawal
  }

  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit
  alias Explorer.Chain.Celo.ElectionReward, as: CeloElectionReward

  require Logger

  @typep counter :: non_neg_integer() | nil

  @counters_limit 51
  @types [
    :validations,
    :transactions,
    :token_transfers,
    :token_balances,
    :logs,
    :withdrawals,
    :internal_transactions,
    :beacon_deposits
  ]
  @transactions_types [:transactions_from, :transactions_to, :transactions_contract]

  defp address_hash_to_logs_query(address_hash) do
    from(l in Log, where: l.address_hash == ^address_hash)
  end

  defp address_hash_to_validated_blocks_query(address_hash) do
    from(b in Block, where: b.miner_hash == ^address_hash)
  end

  def check_if_validated_blocks_at_address(address_hash, options \\ []) do
    select_repo(options).exists?(address_hash_to_validated_blocks_query(address_hash))
  end

  def check_if_logs_at_address(address_hash, options \\ []) do
    select_repo(options).exists?(address_hash_to_logs_query(address_hash))
  end

  def check_if_token_transfers_at_address(address_hash, options \\ []) do
    select_repo(options).exists?(from(tt in TokenTransfer, where: tt.from_address_hash == ^address_hash)) ||
      select_repo(options).exists?(from(tt in TokenTransfer, where: tt.to_address_hash == ^address_hash))
  end

  def check_if_tokens_at_address(address_hash, options \\ []) do
    select_repo(options).exists?(address_hash_to_token_balances_query(address_hash))
  end

  @spec check_if_withdrawals_at_address(Hash.Address.t()) :: boolean()
  def check_if_withdrawals_at_address(address_hash, options \\ []) do
    address_hash
    |> Withdrawal.address_hash_to_withdrawals_existence_query()
    |> select_repo(options).exists?()
  end

  @doc """
    Performs all existence checks needed by the address view in a single
    database round trip: `SELECT exists(...), exists(...), ...`.
  """
  @spec address_existence_checks(Hash.Address.t(), Keyword.t()) :: %{
          has_validated_blocks: boolean(),
          has_logs: boolean(),
          has_tokens: boolean(),
          has_token_transfers: boolean(),
          has_beacon_chain_withdrawals: boolean()
        }
  def address_existence_checks(address_hash, options \\ []) do
    validated_blocks_query = address_hash |> address_hash_to_validated_blocks_query() |> select([_], 1)
    logs_query = address_hash |> address_hash_to_logs_query() |> select([_], 1)
    token_balances_query = address_hash |> address_hash_to_token_balances_query() |> select([_], 1)
    token_transfers_from_query = from(tt in TokenTransfer, where: tt.from_address_hash == ^address_hash, select: 1)
    token_transfers_to_query = from(tt in TokenTransfer, where: tt.to_address_hash == ^address_hash, select: 1)
    withdrawals_query = Withdrawal.address_hash_to_withdrawals_existence_query(address_hash)

    query =
      from(f in fragment("SELECT 1"),
        select: %{
          has_validated_blocks: exists(validated_blocks_query),
          has_logs: exists(logs_query),
          has_tokens: exists(token_balances_query),
          has_token_transfers: exists(token_transfers_from_query) or exists(token_transfers_to_query),
          has_beacon_chain_withdrawals: exists(withdrawals_query)
        }
      )

    select_repo(options).one(query)
  end

  @doc """
  Builds a query for collated transactions sent from or received by the given
  address, optionally bounded by a `(from_block_number, to_block_number]`
  block range (either bound may be `nil` to leave that side open).
  """
  @spec address_hash_to_transaction_count_query(
          Hash.Address.t(),
          Block.block_number() | nil,
          Block.block_number() | nil
        ) :: Ecto.Query.t()
  def address_hash_to_transaction_count_query(address_hash, from_block_number \\ nil, to_block_number \\ nil) do
    dynamic = Transaction.where_transactions_to_from(address_hash)

    Transaction
    |> where([transaction], ^dynamic)
    |> where_block_number_in_range(from_block_number, to_block_number)
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Block.t/0` validated by the address with the given `hash`.
  """
  @spec address_to_validation_count(Hash.Address.t(), [Chain.api?()]) :: non_neg_integer()
  def address_to_validation_count(hash, options) do
    query = from(block in Block, where: block.miner_hash == ^hash, select: fragment("COUNT(*)"))

    select_repo(options).one(query)
  end

  @doc """
  Builds a query for the transactions contributing to the gas usage sum of the
  given address, optionally bounded by a `(from_block_number, to_block_number]`
  block range.

  `direction_field` selects which side of the transaction is attributed to the
  address (see `gas_usage_direction_field/1`).
  """
  @spec address_to_gas_usage_sum_query(
          Hash.Address.t(),
          :to_address_hash | :from_address_hash,
          Block.block_number() | nil,
          Block.block_number() | nil
        ) :: Ecto.Query.t()
  def address_to_gas_usage_sum_query(address_hash, direction_field, from_block_number \\ nil, to_block_number \\ nil) do
    Transaction
    |> where([transaction], field(transaction, ^direction_field) == ^address_hash)
    |> where_block_number_in_range(from_block_number, to_block_number)
  end

  @doc """
  Returns the transaction side whose `gas_used` is accumulated into the
  address gas usage counter: incoming transactions for smart contracts,
  outgoing transactions for EOAs (including EOAs with delegated code).

  The address must have `contract_code` loaded.
  """
  @spec gas_usage_direction_field(Address.t()) :: :to_address_hash | :from_address_hash
  def gas_usage_direction_field(address) do
    if Address.smart_contract?(address) && !Address.eoa_with_code?(address) do
      :to_address_hash
    else
      :from_address_hash
    end
  end

  @doc """
  Builds a query for token transfers sent from or received by the given
  address, optionally bounded by a `(from_block_number, to_block_number]`
  block range.
  """
  @spec address_to_token_transfer_count_query(
          Hash.Address.t(),
          Block.block_number() | nil,
          Block.block_number() | nil
        ) :: Ecto.Query.t()
  def address_to_token_transfer_count_query(address_hash, from_block_number \\ nil, to_block_number \\ nil) do
    TokenTransfer
    |> where(
      [token_transfer],
      token_transfer.to_address_hash == ^address_hash or token_transfer.from_address_hash == ^address_hash
    )
    |> where_block_number_in_range(from_block_number, to_block_number)
  end

  defp where_block_number_in_range(query, from_block_number, to_block_number) do
    query
    |> then(fn q ->
      if is_nil(from_block_number), do: q, else: where(q, [t], t.block_number > ^from_block_number)
    end)
    |> then(fn q ->
      if is_nil(to_block_number), do: q, else: where(q, [t], t.block_number <= ^to_block_number)
    end)
  end

  def address_hash_to_token_balances_query(address_hash) do
    from(
      tb in CurrentTokenBalance,
      where: tb.address_hash == ^address_hash,
      where: tb.value > 0 or tb.token_type == "ERC-7984"
    )
  end

  defp address_hash_to_internal_transactions_limited_count_query(address_hash, options) do
    query_to_address_hash_wrapped =
      InternalTransaction
      |> InternalTransaction.where_nonpending_operation()
      |> InternalTransaction.where_address_fields_match(address_hash, :to, options)
      |> InternalTransaction.where_is_different_from_parent_transaction()
      |> limit(@counters_limit)
      |> wrapped_union_subquery()

    query_from_address_hash_wrapped =
      InternalTransaction
      |> InternalTransaction.where_nonpending_operation()
      |> InternalTransaction.where_address_fields_match(address_hash, :from_address_hash, options)
      |> InternalTransaction.where_is_different_from_parent_transaction()
      |> limit(@counters_limit)
      |> wrapped_union_subquery()

    query_to_address_hash_wrapped
    |> union_all(^query_from_address_hash_wrapped)
    |> wrapped_union_subquery()
  end

  defp address_hash_to_beacon_deposits_unordered_query(address_hash) do
    from(
      deposit in BeaconDeposit,
      where: deposit.from_address_hash == ^address_hash
    )
  end

  @spec address_limited_counters(Hash.t(), Keyword.t()) :: %{atom() => counter}
  def address_limited_counters(address_hash, options) do
    cached_counters =
      Enum.reduce(@types, %{}, fn type, acc ->
        case AddressTabsElementsCount.get_counter(type, address_hash) do
          {_datetime, counter, status} ->
            Map.put(acc, type, {status, counter})

          _ ->
            acc
        end
      end)

    start = System.monotonic_time()

    validations_count_task =
      configure_task(
        :validations,
        cached_counters,
        address_hash_to_validated_blocks_query(address_hash),
        address_hash,
        options
      )

    transactions_from_count_task =
      run_or_ignore(cached_counters[:transactions], :transactions_from, address_hash, fn ->
        result =
          Transaction
          |> where([t], t.from_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :millisecond)

        Logger.debug("Time consumed for transactions_from_count_task for #{address_hash} is #{diff}ms")

        AddressTabsElementsCount.save_transactions_counter_progress(address_hash, %{
          transactions_types: [:transactions_from],
          transactions_from: result
        })

        AddressTabsElementsCount.drop_task(:transactions_from, address_hash)

        {:transactions_from, result}
      end)

    transactions_to_count_task =
      run_or_ignore(cached_counters[:transactions], :transactions_to, address_hash, fn ->
        result =
          Transaction
          |> where([t], t.to_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :millisecond)

        Logger.debug("Time consumed for transactions_to_count_task for #{address_hash} is #{diff}ms")

        AddressTabsElementsCount.save_transactions_counter_progress(address_hash, %{
          transactions_types: [:transactions_to],
          transactions_to: result
        })

        AddressTabsElementsCount.drop_task(:transactions_to, address_hash)

        {:transactions_to, result}
      end)

    transactions_created_contract_count_task =
      run_or_ignore(cached_counters[:transactions], :transactions_contract, address_hash, fn ->
        result =
          Transaction
          |> where([t], t.created_contract_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :millisecond)

        Logger.debug("Time consumed for transactions_created_contract_count_task for #{address_hash} is #{diff}ms")

        AddressTabsElementsCount.save_transactions_counter_progress(address_hash, %{
          transactions_types: [:transactions_contract],
          transactions_contract: result
        })

        AddressTabsElementsCount.drop_task(:transactions_contract, address_hash)

        {:transactions_contract, result}
      end)

    token_transfers_count_task =
      configure_task(
        :token_transfers,
        cached_counters,
        address_to_token_transfer_count_query(address_hash),
        address_hash,
        options
      )

    token_balances_count_task =
      configure_task(
        :token_balances,
        cached_counters,
        address_hash_to_token_balances_query(address_hash),
        address_hash,
        options
      )

    logs_count_task =
      configure_task(
        :logs,
        cached_counters,
        address_hash_to_logs_query(address_hash),
        address_hash,
        options
      )

    withdrawals_count_task =
      configure_task(
        :withdrawals,
        cached_counters,
        Withdrawal.address_hash_to_withdrawals_unordered_query(address_hash),
        address_hash,
        options
      )

    internal_transactions_count_task =
      configure_task(
        :internal_transactions,
        cached_counters,
        address_hash_to_internal_transactions_limited_count_query(address_hash, options),
        address_hash,
        options
      )

    celo_election_rewards_count_task =
      if chain_identity() == {:optimism, :celo} do
        configure_task(
          :celo_election_rewards,
          cached_counters,
          CeloElectionReward.address_hash_to_rewards_query(address_hash),
          address_hash,
          options
        )
      else
        nil
      end

    beacon_deposits_count_task =
      if Application.get_env(:explorer, :chain_type) == :ethereum do
        configure_task(
          :beacon_deposits,
          cached_counters,
          address_hash_to_beacon_deposits_unordered_query(address_hash),
          address_hash,
          options
        )
      end

    map =
      [
        validations_count_task,
        transactions_from_count_task,
        transactions_to_count_task,
        transactions_created_contract_count_task,
        token_transfers_count_task,
        token_balances_count_task,
        logs_count_task,
        withdrawals_count_task,
        internal_transactions_count_task,
        celo_election_rewards_count_task,
        beacon_deposits_count_task
      ]
      |> Enum.reject(&is_nil/1)
      |> Task.yield_many(:timer.seconds(1))
      |> Enum.reduce(
        Map.merge(prepare_cache_values(cached_counters), %{transactions_types: [], transactions_hashes: []}),
        fn {task, res}, acc ->
          case res do
            {:ok, {transactions_type, transactions_hashes}} when transactions_type in @transactions_types ->
              acc
              |> (&Map.put(&1, :transactions_types, [transactions_type | &1[:transactions_types]])).()
              |> (&Map.put(&1, :transactions_hashes, &1[:transactions_hashes] ++ transactions_hashes)).()

            {:ok, {type, counter}} ->
              Map.put(acc, type, counter)

            {:exit, reason} ->
              Logger.warning(fn ->
                [
                  "Query fetching address counters for #{address_hash} terminated: #{inspect(reason)}"
                ]
              end)

              acc

            nil ->
              Logger.warning(fn ->
                [
                  "Query fetching address counters for #{address_hash} timed out."
                ]
              end)

              Task.ignore(task)

              acc
          end
        end
      )
      |> process_transactions_counter()

    map
  end

  defp run_or_ignore({ok, _counter}, _type, _address_hash, _fun) when ok in [:up_to_date, :limit_value], do: nil

  defp run_or_ignore(_, type, address_hash, fun) do
    if !AddressTabsElementsCount.get_task(type, address_hash) do
      AddressTabsElementsCount.set_task(type, address_hash)

      Task.async(fun)
    end
  end

  defp configure_task(counter_type, cache, query, address_hash, options) do
    address_hash = to_string(address_hash)
    start = System.monotonic_time()

    run_or_ignore(cache[counter_type], counter_type, address_hash, fn ->
      result =
        query
        |> count(options, counter_type)

      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :millisecond)

      Logger.debug("Time consumed for #{counter_type} counter task for #{address_hash} is #{diff}ms")

      AddressTabsElementsCount.set_counter(counter_type, address_hash, result)
      AddressTabsElementsCount.drop_task(counter_type, address_hash)

      {counter_type, result}
    end)
  end

  defp count(query, options, :internal_transactions) do
    query
    |> select_repo(options).all()
    |> InternalTransaction.deduplicate_and_trim_internal_transactions(%PagingOptions{page_size: @counters_limit})
    |> Enum.count()
  end

  defp count(query, options, _counter_type) do
    query
    |> limit(@counters_limit)
    |> select_repo(options).aggregate(:count)
  end

  defp process_transactions_counter(
         %{transactions_types: [_ | _] = transactions_types, transactions_hashes: hashes} = map
       ) do
    counter = hashes |> Enum.uniq() |> Enum.count() |> min(@counters_limit)

    if Enum.count(transactions_types) == 3 || counter == @counters_limit do
      map |> Map.put(:transactions, counter)
    else
      map
    end
  end

  defp process_transactions_counter(map), do: map

  defp prepare_cache_values(cached_counters) do
    Enum.reduce(cached_counters, %{}, fn
      {k, {_, counter}}, acc ->
        Map.put(acc, k, counter)

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  @doc """
    Returns all possible transactions type
  """
  @spec transactions_types :: list(atom)
  def transactions_types, do: @transactions_types

  @doc """
    Returns max counter value
  """
  @spec counters_limit :: integer()
  def counters_limit, do: @counters_limit
end
