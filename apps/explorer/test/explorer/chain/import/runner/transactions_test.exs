# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.TransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Block, SignedAuthorization, Transaction, Wei}
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

    test "recollated transactions keep their type and fee fields" do
      max_priority_fee_per_gas = %Wei{value: Decimal.new(1_000_000_000)}
      max_fee_per_gas = %Wei{value: Decimal.new(3_000_000_000)}

      reorg = insert(:block)

      reorg_transaction =
        :transaction
        |> insert(type: 2, max_priority_fee_per_gas: max_priority_fee_per_gas, max_fee_per_gas: max_fee_per_gas)
        |> with_block(reorg)

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

      # the transaction of the discarded block becomes pending, but the fields of the signed transaction stay
      assert %{block_hash: nil, type: 2} = pending_transaction = Repo.get_by(Transaction, hash: reorg_transaction.hash)
      assert Decimal.eq?(pending_transaction.max_priority_fee_per_gas.value, max_priority_fee_per_gas.value)
      assert Decimal.eq?(pending_transaction.max_fee_per_gas.value, max_fee_per_gas.value)
    end

    test "signed authorizations of recollated transactions lose their statuses" do
      reorg = insert(:block)

      reorg_transaction = :transaction |> insert(type: 4) |> with_block(reorg)
      insert(:signed_authorization, transaction: reorg_transaction, index: 0, status: :ok)
      insert(:signed_authorization, transaction: reorg_transaction, index: 1, status: :invalid_signature)

      # an authorization of a transaction that stays in its block is not changed
      other_transaction = :transaction |> insert(type: 4) |> with_block()
      insert(:signed_authorization, transaction: other_transaction, index: 0, status: :ok)

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

      assert %{block_hash: nil} = Repo.get_by(Transaction, hash: reorg_transaction.hash)

      assert [nil, nil] =
               Repo.all(
                 from(authorization in SignedAuthorization,
                   where: authorization.transaction_hash == ^reorg_transaction.hash,
                   order_by: authorization.index,
                   select: authorization.status
                 )
               )

      assert %{status: :ok} = Repo.get_by(SignedAuthorization, transaction_hash: other_transaction.hash, index: 0)
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
