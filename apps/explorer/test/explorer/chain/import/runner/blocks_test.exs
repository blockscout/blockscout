defmodule Explorer.Chain.Import.Runner.BlocksTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2, select: 2, where: 2]

  import Explorer.Chain.Import.RunnerCase, only: [insert_address_with_token_balances: 1, update_holder_count!: 2]

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.{Blocks, Transaction}
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Repo

  describe "run/1" do
    setup do
      block = insert(:block, consensus: true)

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      %{consensus_block: block, options: options}
    end

    test "derive_transaction_forks replaces hash on conflicting (uncle_hash, index)", %{
      consensus_block: %Block{hash: block_hash, miner_hash: miner_hash, number: block_number} = consensus_block,
      options: options
    } do
      transaction =
        :transaction
        |> insert()
        |> with_block(consensus_block)

      block_params =
        params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: false)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               0

      assert count(Transaction.Fork) == 0

      # re-org consensus_block to uncle

      assert {:ok, %{derive_transaction_forks: [_]}} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()

      assert Repo.aggregate(where(Block, consensus: false), :count, :number) == 1

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               1

      assert count(Transaction.Fork) == 1

      non_consensus_transaction = Repo.get(Transaction, transaction.hash)
      non_consensus_block = Repo.get(Block, block_hash)

      # Make it consensus again
      new_consensus_block =
        non_consensus_block
        |> Block.changeset(%{consensus: true})
        |> Repo.update!()

      with_block(non_consensus_transaction, new_consensus_block)

      ctid = Repo.one!(from(transaction_fork in Transaction.Fork, select: "ctid"))

      assert Repo.aggregate(from(transaction in Transaction, where: is_nil(transaction.block_number)), :count, :hash) ==
               0

      assert {:ok, %{derive_transaction_forks: []}} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()

      assert Repo.one!(from(transaction_fork in Transaction.Fork, select: "ctid")) == ctid,
             "Tuple was written even though it is not distinct"
    end

    test "delete_address_current_token_balances deletes rows with matching block number when consensus is true",
         %{consensus_block: %Block{number: block_number} = block, options: options} do
      %Address.CurrentTokenBalance{address_hash: address_hash, token_contract_address_hash: token_contract_address_hash} =
        insert(:address_current_token_balance, block_number: block_number)

      assert count(Address.CurrentTokenBalance) == 1

      assert {:ok,
              %{
                delete_address_current_token_balances: [
                  %{address_hash: ^address_hash, token_contract_address_hash: ^token_contract_address_hash}
                ]
              }} = run_block_consensus_change(block, true, options)

      assert count(Address.CurrentTokenBalance) == 0
    end

    test "delete_address_current_token_balances does not delete rows with matching block number when consensus is false",
         %{consensus_block: %Block{number: block_number} = block, options: options} do
      %Address.CurrentTokenBalance{} = insert(:address_current_token_balance, block_number: block_number)

      count = 1

      assert count(Address.CurrentTokenBalance) == count

      assert {:ok,
              %{
                delete_address_current_token_balances: []
              }} = run_block_consensus_change(block, false, options)

      assert count(Address.CurrentTokenBalance) == count
    end

    test "derive_address_current_token_balances inserts rows if there is an address_token_balance left for the rows deleted by delete_address_current_token_balances",
         %{consensus_block: %Block{number: block_number} = block, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      %Address{hash: address_hash} =
        insert_address_with_token_balances(%{
          previous: %{value: 1},
          current: %{block_number: block_number, value: 2},
          token_contract_address_hash: token_contract_address_hash
        })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 1)

      assert count(Address.TokenBalance) == 2
      assert count(Address.CurrentTokenBalance) == 1

      previous_block_number = block_number - 1

      assert {:ok,
              %{
                delete_address_current_token_balances: [
                  %{
                    address_hash: ^address_hash,
                    token_contract_address_hash: ^token_contract_address_hash
                  }
                ],
                delete_address_token_balances: [
                  %{
                    address_hash: ^address_hash,
                    token_contract_address_hash: ^token_contract_address_hash,
                    block_number: ^block_number
                  }
                ],
                derive_address_current_token_balances: [
                  %{
                    address_hash: ^address_hash,
                    token_contract_address_hash: ^token_contract_address_hash,
                    block_number: ^previous_block_number
                  }
                ],
                # no updates because it both deletes and derives a holder
                blocks_update_token_holder_counts: []
              }} = run_block_consensus_change(block, true, options)

      assert count(Address.TokenBalance) == 1
      assert count(Address.CurrentTokenBalance) == 1

      previous_value = Decimal.new(1)

      assert %Address.CurrentTokenBalance{block_number: ^previous_block_number, value: ^previous_value} =
               Repo.get_by(Address.CurrentTokenBalance,
                 address_hash: address_hash,
                 token_contract_address_hash: token_contract_address_hash
               )
    end

    test "a non-holder reverting to a holder increases the holder_count",
         %{consensus_block: %Block{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      non_holder_reverts_to_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 0)

      block_params = params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: true)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]

      assert {:ok,
              %{
                blocks_update_token_holder_counts: [
                  %{
                    contract_address_hash: ^token_contract_address_hash,
                    holder_count: 1
                  }
                ]
              }} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()
    end

    test "a holder reverting to a non-holder decreases the holder_count",
         %{consensus_block: %Block{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      holder_reverts_to_non_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 1)

      block_params = params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: true)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]

      assert {:ok,
              %{
                blocks_update_token_holder_counts: [
                  %{
                    contract_address_hash: ^token_contract_address_hash,
                    holder_count: 0
                  }
                ]
              }} =
               Multi.new()
               |> Blocks.run(changes_list, options)
               |> Repo.transaction()
    end

    test "a non-holder becoming and a holder becoming while a holder becomes a non-holder cancels out and holder_count does not change",
         %{consensus_block: %Block{number: block_number} = block, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      non_holder_reverts_to_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      holder_reverts_to_non_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 1)

      assert {:ok,
              %{
                # cancels out to no change
                blocks_update_token_holder_counts: []
              }} = run_block_consensus_change(block, true, options)
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
  end

  defp holder_reverts_to_non_holder(%{
         current: %{block_number: current_block_number},
         token_contract_address_hash: token_contract_address_hash
       }) do
    insert_address_with_token_balances(%{
      previous: %{value: 0},
      current: %{block_number: current_block_number, value: 1},
      token_contract_address_hash: token_contract_address_hash
    })
  end

  defp non_holder_reverts_to_holder(%{
         current: %{block_number: current_block_number},
         token_contract_address_hash: token_contract_address_hash
       }) do
    insert_address_with_token_balances(%{
      previous: %{value: 1},
      current: %{block_number: current_block_number, value: 0},
      token_contract_address_hash: token_contract_address_hash
    })
  end

  defp run_block_consensus_change(
         %Block{hash: block_hash, miner_hash: miner_hash, number: block_number},
         consensus,
         options
       ) do
    block_params =
      params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: consensus)

    %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
    changes_list = [block_changes]

    Multi.new()
    |> Blocks.run(changes_list, options)
    |> Repo.transaction()
  end
end
