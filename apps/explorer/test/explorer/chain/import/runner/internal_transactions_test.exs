defmodule Explorer.Chain.Import.Runner.InternalTransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Data, Wei, Transaction}
  alias Explorer.Chain.Import.Runner.InternalTransactions

  describe "run/1" do
    test "transaction's status becomes :error when its internal_transaction has an error" do
      transaction = insert(:transaction) |> with_block(status: :ok)

      assert :ok == transaction.status

      index = 0
      error = "Reverted"

      internal_transaction_changes = make_internal_transaction_changes(transaction.hash, index, error)

      assert {:ok, _} = run_internal_transactions([internal_transaction_changes])

      assert :error == Repo.get(Transaction, transaction.hash).status
    end
  end

  defp run_internal_transactions(changes_list) when is_list(changes_list) do
    Multi.new()
    |> InternalTransactions.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end

  defp make_internal_transaction_changes(transaction_hash, index, error) do
    %{
      from_address_hash: insert(:address).hash,
      to_address_hash: insert(:address).hash,
      call_type: :call,
      gas: 22234,
      gas_used:
        if is_nil(error) do
          18920
        else
          nil
        end,
      input: %Data{bytes: <<1>>},
      output:
        if is_nil(error) do
          %Data{bytes: <<2>>}
        else
          nil
        end,
      index: index,
      trace_address: [],
      transaction_hash: transaction_hash,
      type: :call,
      value: Wei.from(Decimal.new(1), :wei),
      error: error
    }
  end
end
