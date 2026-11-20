# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.AddressCoinBalancesTransactionsTest do
  # not async: the tests change the application env
  use ExUnit.Case

  alias Explorer.Factory
  alias Indexer.Fetcher.InternalTransaction
  alias Indexer.Fetcher.InternalTransaction.Supervisor, as: InternalTransactionSupervisor
  alias Indexer.Transform.AddressCoinBalances

  setup do
    initial_fetcher_env = Application.get_env(:indexer, InternalTransaction)
    initial_supervisor_env = Application.get_env(:indexer, InternalTransactionSupervisor)
    initial_trace_block_ranges = Application.get_env(:indexer, :trace_block_ranges)
    initial_chain_type = Application.get_env(:explorer, :chain_type)

    on_exit(fn ->
      Application.put_env(:explorer, :chain_type, initial_chain_type)
      Application.put_env(:indexer, InternalTransaction, initial_fetcher_env)
      Application.put_env(:indexer, InternalTransactionSupervisor, initial_supervisor_env)
      Application.put_env(:indexer, :trace_block_ranges, initial_trace_block_ranges)
    end)

    from_address_hash = to_string(Factory.address_hash())
    to_address_hash = to_string(Factory.address_hash())

    transaction_params = %{
      block_number: 10,
      from_address_hash: from_address_hash,
      to_address_hash: to_address_hash,
      value: 0
    }

    %{
      transaction_params: transaction_params,
      from: %{address_hash: from_address_hash, block_number: 10},
      to: %{address_hash: to_address_hash, block_number: 10}
    }
  end

  defp set_internal_transactions_fetcher(disabled?) do
    initial = Application.get_env(:indexer, InternalTransaction)
    Application.put_env(:indexer, InternalTransaction, Keyword.merge(initial || [], disabled?: disabled?))
  end

  describe "params_set/1 with transactions" do
    test "skips the recipient of a zero-value transaction when the block is traced", %{
      transaction_params: transaction_params,
      from: from
    } do
      set_internal_transactions_fetcher(false)

      assert AddressCoinBalances.params_set(%{transactions_params: [transaction_params]}) == MapSet.new([from])
    end

    test "extracts the recipient of a transaction with a value when the block is traced", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      set_internal_transactions_fetcher(false)

      assert AddressCoinBalances.params_set(%{transactions_params: [%{transaction_params | value: 1}]}) ==
               MapSet.new([from, to])
    end

    test "extracts the recipient of a zero-value transaction when the internal transactions fetcher is disabled", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      set_internal_transactions_fetcher(true)

      assert AddressCoinBalances.params_set(%{transactions_params: [transaction_params]}) == MapSet.new([from, to])
    end

    test "extracts the recipient when the fetcher is disabled although its supervisor is not", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      initial_supervisor_env = Application.get_env(:indexer, InternalTransactionSupervisor)

      Application.put_env(
        :indexer,
        InternalTransactionSupervisor,
        Keyword.merge(initial_supervisor_env || [], disabled?: false)
      )

      set_internal_transactions_fetcher(true)

      assert AddressCoinBalances.params_set(%{transactions_params: [transaction_params]}) == MapSet.new([from, to])
    end

    test "extracts the recipient of a zero-value transaction when the block is outside the trace ranges", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      set_internal_transactions_fetcher(false)
      Application.put_env(:indexer, :trace_block_ranges, "100..latest")

      assert AddressCoinBalances.params_set(%{transactions_params: [transaction_params]}) == MapSet.new([from, to])
    end

    test "extracts the recipient of a zero-value transaction that is never traced", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      set_internal_transactions_fetcher(false)
      Application.put_env(:explorer, :chain_type, :zetachain)

      assert AddressCoinBalances.params_set(%{transactions_params: [Map.put(transaction_params, :type, 88)]}) ==
               MapSet.new([from, to])

      assert AddressCoinBalances.params_set(%{transactions_params: [Map.put(transaction_params, :type, 2)]}) ==
               MapSet.new([from])
    end

    test "extracts the recipient when the transaction has no value field", %{
      transaction_params: transaction_params,
      from: from,
      to: to
    } do
      set_internal_transactions_fetcher(false)

      assert AddressCoinBalances.params_set(%{transactions_params: [Map.delete(transaction_params, :value)]}) ==
               MapSet.new([from, to])
    end
  end
end
