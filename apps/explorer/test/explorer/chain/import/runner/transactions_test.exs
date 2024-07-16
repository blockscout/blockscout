defmodule Explorer.Chain.Import.Runner.TransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Block, Transaction}
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

    test "recollated transactions replaced with empty data" do
      reorg = insert(:block)
      reorg_transaction = :transaction |> insert() |> with_block(reorg)
      transaction = :transaction |> insert() |> with_block(reorg)
      reorg |> Block.changeset(%{consensus: false}) |> Repo.update()
      block = insert(:block, consensus: true, number: reorg.number)

      transaction_params = %{
        block_hash: block.hash,
        block_number: block.number,
        gas_used: transaction.gas_used,
        cumulative_gas_used: transaction.cumulative_gas_used,
        index: transaction.index,
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
        value: transaction.value
      }

      assert {:ok, _} = run_transactions([transaction_params])

      assert %{
               block_hash: nil,
               block_number: nil,
               gas_used: nil,
               cumulative_gas_used: nil,
               index: nil,
               status: nil,
               error: nil
             } = Repo.get_by(Transaction, hash: reorg_transaction.hash)

      assert not is_nil(Repo.get_by(Transaction, hash: transaction.hash).block_hash)
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
