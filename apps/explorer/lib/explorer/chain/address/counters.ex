defmodule Explorer.Chain.Address.Counters do
  @moduledoc """
    Functions related to Explorer.Chain.Address counters
  """
  import Ecto.Query, only: [from: 2, limit: 2, select: 3, subquery: 1, union: 2, where: 3]

  import Explorer.Chain,
    only: [select_repo: 1, wrapped_union_subquery: 1]

  alias Explorer.{Chain, Repo}

  alias Explorer.Counters.{
    AddressesCounter,
    AddressesWithBalanceCounter,
    AddressTokenTransfersCounter,
    AddressTransactionsCounter,
    AddressTransactionsGasUsageCounter
  }

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CurrentTokenBalance,
    Block,
    Hash,
    InternalTransaction,
    Log,
    TokenTransfer,
    Transaction,
    Withdrawal
  }

  alias Explorer.Chain.Cache.Helper, as: CacheHelper

  require Logger

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

  defp address_hash_to_coin_balances(address_hash) do
    query =
      from(
        cb in CoinBalance,
        where: cb.address_hash == ^address_hash,
        where: not is_nil(cb.value),
        select_merge: %{
          delta: fragment("? - coalesce(lead(?, 1) over (order by ? desc), 0)", cb.value, cb.value, cb.block_number)
        }
      )

    from(balance in subquery(query),
      where: balance.delta != 0
    )
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
    |> Withdrawal.address_hash_to_withdrawals_unordered_query()
    |> select_repo(options).exists?()
  end

  @doc """
  Gets from the cache the count of `t:Explorer.Chain.Address.t/0`'s where the `fetched_coin_balance` is > 0
  """
  @spec count_addresses_with_balance_from_cache :: non_neg_integer()
  def count_addresses_with_balance_from_cache do
    AddressesWithBalanceCounter.fetch()
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Address.t/0`.

  Estimated count of addresses.
  """
  @spec address_estimated_count() :: non_neg_integer()
  def address_estimated_count(options \\ []) do
    cached_value = AddressesCounter.fetch()

    if is_nil(cached_value) || cached_value == 0 do
      count = CacheHelper.estimated_count_from("addresses", options)

      max(count, 0)
    else
      cached_value
    end
  end

  @doc """
  Counts the number of all addresses.

  This function should be used with caution. In larger databases, it may take a
  while to have the return back.
  """
  def count_addresses do
    Repo.aggregate(Address, :count, timeout: :infinity)
  end

  @doc """
  Get the total number of transactions sent by the address with the given hash according to the last block indexed.

  We have to increment +1 in the last nonce result because it works like an array position, the first
  nonce has the value 0. When last nonce is nil, it considers that the given address has 0 transactions.
  """
  @spec total_transactions_sent_by_address(Hash.Address.t()) :: non_neg_integer()
  def total_transactions_sent_by_address(address_hash) do
    last_nonce =
      address_hash
      |> Transaction.last_nonce_by_address_query()
      |> Repo.one(timeout: :infinity)

    case last_nonce do
      nil -> 0
      value -> value + 1
    end
  end

  def address_hash_to_transaction_count_query(address_hash) do
    from(
      transaction in Transaction,
      where: transaction.to_address_hash == ^address_hash or transaction.from_address_hash == ^address_hash
    )
  end

  @spec address_hash_to_transaction_count(Hash.Address.t()) :: non_neg_integer()
  def address_hash_to_transaction_count(address_hash) do
    query = address_hash_to_transaction_count_query(address_hash)

    Repo.aggregate(query, :count, :hash, timeout: :infinity)
  end

  @spec address_to_transaction_count(Address.t()) :: non_neg_integer()
  def address_to_transaction_count(address) do
    address_hash_to_transaction_count(address.hash)
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
  Counts the number of addresses with fetched coin balance > 0.

  This function should be used with caution. In larger databases, it may take a
  while to have the return back.
  """
  def count_addresses_with_balance do
    Repo.one(
      Address.count_with_fetched_coin_balance(),
      timeout: :infinity
    )
  end

  @spec address_to_incoming_transaction_count(Hash.Address.t()) :: non_neg_integer()
  def address_to_incoming_transaction_count(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :count, :hash, timeout: :infinity)
  end

  @spec address_to_incoming_transaction_gas_usage(Hash.Address.t()) :: Decimal.t() | nil
  def address_to_incoming_transaction_gas_usage(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :sum, :gas_used, timeout: :infinity)
  end

  @spec address_to_outcoming_transaction_gas_usage(Hash.Address.t()) :: Decimal.t() | nil
  def address_to_outcoming_transaction_gas_usage(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.from_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :sum, :gas_used, timeout: :infinity)
  end

  def address_to_token_transfer_count_query(address_hash) do
    from(
      token_transfer in TokenTransfer,
      where: token_transfer.to_address_hash == ^address_hash,
      or_where: token_transfer.from_address_hash == ^address_hash
    )
  end

  @spec address_to_token_transfer_count(Address.t()) :: non_neg_integer()
  def address_to_token_transfer_count(address) do
    query = address_to_token_transfer_count_query(address.hash)

    Repo.aggregate(query, :count, timeout: :infinity)
  end

  def address_hash_to_token_balances_query(address_hash) do
    from(
      tb in CurrentTokenBalance,
      where: tb.address_hash == ^address_hash,
      where: tb.value > 0
    )
  end

  @spec address_to_gas_usage_count(Address.t()) :: Decimal.t() | nil
  def address_to_gas_usage_count(address) do
    if Chain.contract?(address) do
      incoming_transaction_gas_usage = address_to_incoming_transaction_gas_usage(address.hash)

      cond do
        !incoming_transaction_gas_usage ->
          address_to_outcoming_transaction_gas_usage(address.hash)

        Decimal.compare(incoming_transaction_gas_usage, 0) == :eq ->
          address_to_outcoming_transaction_gas_usage(address.hash)

        true ->
          incoming_transaction_gas_usage
      end
    else
      address_to_outcoming_transaction_gas_usage(address.hash)
    end
  end

  def address_counters(address, options \\ []) do
    validation_count_task =
      Task.async(fn ->
        address_to_validation_count(address.hash, options)
      end)

    Task.start_link(fn ->
      transaction_count(address)
    end)

    Task.start_link(fn ->
      token_transfers_count(address)
    end)

    Task.start_link(fn ->
      gas_usage_count(address)
    end)

    [
      validation_count_task
    ]
    |> Task.yield_many(:infinity)
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching address counters terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching address counters timed out."
      end
    end)
    |> List.to_tuple()
  end

  def transaction_count(address) do
    AddressTransactionsCounter.fetch(address)
  end

  def token_transfers_count(address) do
    AddressTokenTransfersCounter.fetch(address)
  end

  def gas_usage_count(address) do
    AddressTransactionsGasUsageCounter.fetch(address)
  end

  @counters_limit 51

  def address_limited_counters(address_hash, options) do
    start = Time.utc_now()

    validations_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> address_hash_to_validated_blocks_query()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for validations_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    transactions_from_count_task =
      Task.async(fn ->
        result =
          Transaction
          |> where([t], t.from_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        Logger.info(
          "Time consumed for transactions_from_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    transactions_to_count_task =
      Task.async(fn ->
        result =
          Transaction
          |> where([t], t.to_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        Logger.info(
          "Time consumed for transactions_to_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    transactions_created_contract_count_task =
      Task.async(fn ->
        result =
          Transaction
          |> where([t], t.created_contract_address_hash == ^address_hash)
          |> Transaction.not_dropped_or_replaced_transactions()
          |> select([t], t.hash)
          |> limit(@counters_limit)
          |> select_repo(options).all()

        Logger.info(
          "Time consumed for transactions_created_contract_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    token_transfer_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> address_to_token_transfer_count_query()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for token_transfer_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    token_balances_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> address_hash_to_token_balances_query()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for token_balances_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    logs_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> address_hash_to_logs_query()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for logs_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    withdrawals_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> Withdrawal.address_hash_to_withdrawals_unordered_query()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for withdrawals_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    internal_txs_count_task =
      Task.async(fn ->
        query_to_address_hash_wrapped =
          InternalTransaction
          |> InternalTransaction.where_nonpending_block()
          |> InternalTransaction.where_address_fields_match(address_hash, :to_address_hash)
          |> InternalTransaction.where_is_different_from_parent_transaction()
          |> limit(@counters_limit)
          |> wrapped_union_subquery()

        query_from_address_hash_wrapped =
          InternalTransaction
          |> InternalTransaction.where_nonpending_block()
          |> InternalTransaction.where_address_fields_match(address_hash, :from_address_hash)
          |> InternalTransaction.where_is_different_from_parent_transaction()
          |> limit(@counters_limit)
          |> wrapped_union_subquery()

        query_created_contract_address_hash_wrapped =
          InternalTransaction
          |> InternalTransaction.where_nonpending_block()
          |> InternalTransaction.where_address_fields_match(address_hash, :created_contract_address_hash)
          |> InternalTransaction.where_is_different_from_parent_transaction()
          |> limit(@counters_limit)
          |> wrapped_union_subquery()

        result =
          query_to_address_hash_wrapped
          |> union(^query_from_address_hash_wrapped)
          |> union(^query_created_contract_address_hash_wrapped)
          |> wrapped_union_subquery()
          |> InternalTransaction.where_is_different_from_parent_transaction()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for internal_txs_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    coin_balances_count_task =
      Task.async(fn ->
        result =
          address_hash
          |> address_hash_to_coin_balances()
          |> limit(@counters_limit)
          |> select_repo(options).aggregate(:count)

        Logger.info(
          "Time consumed for coin_balances_count_task for #{address_hash} is #{Time.diff(Time.utc_now(), start, :millisecond)}ms"
        )

        result
      end)

    {validations, txs_from, txs_to, txs_contract, token_transfers, token_balances, logs, withdrawals, internal_txs,
     coin_balances} =
      [
        validations_count_task,
        transactions_from_count_task,
        transactions_to_count_task,
        transactions_created_contract_count_task,
        token_transfer_count_task,
        token_balances_count_task,
        logs_count_task,
        withdrawals_count_task,
        internal_txs_count_task,
        coin_balances_count_task
      ]
      |> Task.yield_many(:timer.seconds(30))
      |> Enum.map(fn {_task, res} ->
        case res do
          {:ok, result} ->
            result

          {:exit, reason} ->
            Logger.warn(fn ->
              [
                "Query fetching address counters terminated: #{inspect(reason)}"
              ]
            end)

            nil

          nil ->
            Logger.warn(fn ->
              [
                "Query fetching address counters timed out."
              ]
            end)

            nil
        end
      end)
      |> List.to_tuple()

    {validations,
     (sanitize_list(txs_from) ++ sanitize_list(txs_to) ++ sanitize_list(txs_contract)) |> Enum.dedup() |> Enum.count(),
     token_transfers, token_balances, logs, withdrawals, internal_txs, coin_balances}
  end

  defp sanitize_list(nil), do: []
  defp sanitize_list(other), do: other
end
