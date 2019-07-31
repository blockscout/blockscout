defmodule Explorer.Chain.Import.Runner.TransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Chain.Import.Runner.Transactions

  describe "run/1" do
    test "transaction's created_contract_code_indexed_at is modified on update" do
      %Address{hash: address_hash} = insert(:address)

      transaction =
        insert(:transaction,
          created_contract_address_hash: address_hash,
          created_contract_code_indexed_at: DateTime.utc_now()
        )

      assert not is_nil(transaction.created_contract_code_indexed_at)

      non_indexed_transaction_params = %{
        from_address_hash: transaction.from_address.hash,
        gas: transaction.gas,
        gas_price: transaction.gas_price,
        hash: transaction.hash,
        input: transaction.input,
        nonce: transaction.nonce,
        r: transaction.r,
        s: transaction.s,
        to_address_hash: transaction.to_address.hash,
        v: transaction.v,
        value: transaction.value,
        created_contract_address_hash: address_hash,
        created_contract_code_indexed_at: nil
      }

      assert {:ok, _} = run_transactions([non_indexed_transaction_params])

      assert is_nil(Repo.get(Transaction, transaction.hash).created_contract_code_indexed_at)
    end
  end

  defp run_transactions(changes_list) when is_list(changes_list) do
    Multi.new()
    |> Transactions.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
