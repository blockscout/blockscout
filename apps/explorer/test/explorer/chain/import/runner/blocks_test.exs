defmodule Explorer.Chain.Import.Runner.BlocksTest do
  use Explorer.DataCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Ecto.Query, only: [from: 2, select: 2, where: 2]

  import Explorer.Chain.Import.RunnerCase, only: [insert_address_with_token_balances: 1, update_holder_count!: 2]

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.{Blocks, Transactions}
  alias Explorer.Chain.{Address, Block, Transaction, PendingBlockOperation}
  alias Explorer.{Chain, Repo}
  alias Explorer.Utility.MissingBlockRange

  describe "run/1" do
    setup do
      miner = insert(:address)
      block = params_for(:block, consensus: true, miner_hash: miner.hash)

      timestamp = DateTime.utc_now()
      options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

      %{consensus_block: block, options: options}
    end

    test "derive_transaction_forks replaces hash on conflicting (uncle_hash, index)", %{
      consensus_block: %{hash: block_hash, miner_hash: miner_hash, number: block_number},
      options: options
    } do
      consensus_block = insert(:block, %{hash: block_hash, number: block_number})

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

    test "coin balances are deleted and new balances are derived if some blocks lost consensus",
         %{consensus_block: %{number: block_number} = block, options: options} do
      %{hash: address_hash} = address = insert(:address, fetched_coin_balance_block_number: block_number)

      prev_block_number = block_number - 1

      insert(:address_coin_balance, address: address, block_number: block_number)
      %{value: prev_value} = insert(:address_coin_balance, address: address, block_number: prev_block_number)

      assert count(Address.CoinBalance) == 2

      insert(:block, number: block_number, consensus: true)

      assert {:ok,
              %{
                delete_address_coin_balances: [{^address_hash, ^block_number}],
                derive_address_fetched_coin_balances: [
                  %{
                    hash: ^address_hash,
                    fetched_coin_balance: ^prev_value,
                    fetched_coin_balance_block_number: ^prev_block_number
                  }
                ]
              }} = run_block_consensus_change(block, true, options)

      assert %{value: ^prev_value, block_number: ^prev_block_number} = Repo.one(Address.CoinBalance)
    end

    test "derive_address_fetched_coin_balances only updates addresses if its fetched_coin_balance_block_number lost consensus",
         %{consensus_block: %{number: block_number} = block, options: options} do
      %{hash: address_hash} = address = insert(:address, fetched_coin_balance_block_number: block_number)
      address_1 = insert(:address, fetched_coin_balance_block_number: block_number + 2)

      prev_block_number = block_number - 1

      insert(:address_coin_balance, address: address, block_number: block_number)
      %{value: prev_value} = insert(:address_coin_balance, address: address, block_number: prev_block_number)

      insert(:address_coin_balance, address: address_1, block_number: block_number + 2)

      insert(:block, number: block_number, consensus: true)

      assert {:ok,
              %{
                delete_address_coin_balances: [{^address_hash, ^block_number}],
                derive_address_fetched_coin_balances: [
                  %{
                    hash: ^address_hash,
                    fetched_coin_balance: ^prev_value,
                    fetched_coin_balance_block_number: ^prev_block_number
                  }
                ]
              }} = run_block_consensus_change(block, true, options)
    end

    test "delete_address_current_token_balances deletes rows with matching block number when consensus is true",
         %{consensus_block: %{number: block_number} = block, options: options} do
      %Address.CurrentTokenBalance{address_hash: address_hash, token_contract_address_hash: token_contract_address_hash} =
        insert(:address_current_token_balance, block_number: block_number)

      assert count(Address.CurrentTokenBalance) == 1

      insert(:block, number: block_number, consensus: true)

      assert {:ok,
              %{
                delete_address_current_token_balances: [
                  %{address_hash: ^address_hash, token_contract_address_hash: ^token_contract_address_hash}
                ]
              }} = run_block_consensus_change(block, true, options)

      assert count(Address.CurrentTokenBalance) == 0
    end

    test "delete_address_current_token_balances does not delete rows with matching block number when consensus is false",
         %{consensus_block: %{number: block_number} = block, options: options} do
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
         %{consensus_block: %{number: block_number} = block, options: options} do
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

      insert(:block, number: block_number, consensus: true)

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
         %{consensus_block: %{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      non_holder_reverts_to_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 0)

      insert(:block, number: block_number, consensus: true)

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
         %{consensus_block: %{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      token = insert(:token)
      token_contract_address_hash = token.contract_address_hash

      holder_reverts_to_non_holder(%{
        current: %{block_number: block_number},
        token_contract_address_hash: token_contract_address_hash
      })

      # Token must exist with non-`nil` `holder_count` for `blocks_update_token_holder_counts` to update
      update_holder_count!(token_contract_address_hash, 1)

      insert(:block, number: block_number, consensus: true)

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
         %{consensus_block: %{number: block_number} = block, options: options} do
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

    # Regression test for https://github.com/poanetwork/blockscout/issues/1644
    test "discards neighboring blocks if they aren't related to the current one because of reorg and/or import timeout",
         %{consensus_block: %{number: block_number, hash: block_hash, miner_hash: miner_hash}, options: options} do
      insert(:block, %{number: block_number, hash: block_hash})
      old_block1 = params_for(:block, miner_hash: miner_hash, parent_hash: block_hash, number: block_number + 1)

      new_block1 = params_for(:block, miner_hash: miner_hash, parent_hash: block_hash, number: block_number + 1)
      new_block2 = params_for(:block, miner_hash: miner_hash, parent_hash: new_block1.hash, number: block_number + 2)

      range = block_number..(block_number + 2)

      insert_block(new_block1, options)
      insert_block(new_block2, options)
      assert Chain.missing_block_number_ranges(range) == []

      insert_block(old_block1, options)
      assert Chain.missing_block_number_ranges(range) == [(block_number + 2)..(block_number + 2)]

      insert_block(new_block2, options)
      assert Chain.missing_block_number_ranges(range) == [(block_number + 1)..(block_number + 1)]

      insert_block(new_block1, options)
      assert Chain.missing_block_number_ranges(range) == []
    end

    # Regression test for https://github.com/poanetwork/blockscout/issues/1911
    test "forces block refetch if transaction is re-collated in a different block",
         %{consensus_block: %{number: block_number, hash: block_hash, miner_hash: miner_hash}, options: options} do
      insert(:block, %{number: block_number, hash: block_hash})
      new_block1 = params_for(:block, miner_hash: miner_hash, parent_hash: block_hash, number: block_number + 1)
      new_block2 = params_for(:block, miner_hash: miner_hash, parent_hash: new_block1.hash, number: block_number + 2)

      range = block_number..(block_number + 2)

      insert_block(new_block1, options)
      insert_block(new_block2, options)
      assert Chain.missing_block_number_ranges(range) == []

      trans_hash = transaction_hash()

      transaction1 = transaction_params_with_block([hash: trans_hash], new_block1)
      insert_transaction(transaction1, options)
      assert Chain.missing_block_number_ranges(range) == []

      transaction2 = transaction_params_with_block([hash: trans_hash], new_block2)
      insert_transaction(transaction2, options)
      assert Chain.missing_block_number_ranges(range) == [(block_number + 1)..(block_number + 1)]
    end

    test "removes duplicate blocks (by hash) before inserting",
         %{consensus_block: %{number: _, hash: _block_hash, miner_hash: miner_hash}, options: options} do
      new_block = params_for(:block, miner_hash: miner_hash, consensus: true)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, new_block)

      result =
        Multi.new()
        |> Blocks.run([block_changes, block_changes], options)
        |> Repo.transaction()

      assert {:ok, %{blocks: [%{hash: _block_hash, consensus: true}]}} = result
    end

    test "inserts missing ranges if there are blocks that lost consensus",
         %{consensus_block: %{number: block_number} = block, options: options} do
      block1 = params_for(:block, consensus: true, miner_hash: insert(:address).hash)

      block2 =
        params_for(:block,
          consensus: true,
          miner_hash: insert(:address).hash,
          parent_hash: block1.hash,
          number: block.number + 1
        )

      insert_block(block, options)
      insert_block(block2, options)

      Process.sleep(100)

      assert %{from_number: ^block_number, to_number: ^block_number} = Repo.one(MissingBlockRange)
    end

    test "inserts pending_block_operations only for consensus blocks",
         %{consensus_block: %{miner_hash: miner_hash}, options: options} do
      %{number: number, hash: hash} = new_block = params_for(:block, miner_hash: miner_hash, consensus: true)
      new_block1 = params_for(:block, miner_hash: miner_hash, consensus: false)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, new_block)
      %Ecto.Changeset{valid?: true, changes: block_changes1} = Block.changeset(%Block{}, new_block1)

      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)

      Multi.new()
      |> Blocks.run([block_changes, block_changes1], options)
      |> Repo.transaction()

      assert %{block_number: ^number, block_hash: ^hash} = Repo.one(PendingBlockOperation)
    end

    test "inserts pending_block_operations only for actually inserted blocks",
         %{consensus_block: %{miner_hash: miner_hash}, options: options} do
      %{number: number, hash: hash} = new_block = params_for(:block, miner_hash: miner_hash, consensus: true)
      new_block1 = params_for(:block, miner_hash: miner_hash, consensus: true)

      miner = Repo.get_by(Address, hash: miner_hash)

      insert(:block, Map.put(new_block1, :miner, miner))

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, new_block)
      %Ecto.Changeset{valid?: true, changes: block_changes1} = Block.changeset(%Block{}, new_block1)

      config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(config, :block_traceable?, true))

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, config) end)

      Multi.new()
      |> Blocks.run([block_changes, block_changes1], options)
      |> Repo.transaction()

      assert %{block_number: ^number, block_hash: ^hash} = Repo.one(PendingBlockOperation)
    end

    test "change instance owner if was token transfer in older blocks",
         %{consensus_block: %{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      block_number = block_number + 2
      consensus_block = insert(:block, %{hash: block_hash, number: block_number})

      transaction =
        :transaction
        |> insert()
        |> with_block(consensus_block)

      token_address = insert(:contract_address)
      insert(:token, contract_address: token_address, type: "ERC-721")
      id = Decimal.new(1)

      tt =
        insert(:token_transfer,
          token_ids: [id],
          token_type: "ERC-721",
          transaction: transaction,
          token_contract_address: token_address,
          block_number: block_number,
          block: consensus_block,
          log_index: 123
        )

      %{hash: hash_1} = params_for(:block, consensus: true, miner_hash: miner_hash)
      consensus_block_1 = insert(:block, %{hash: hash_1, number: block_number - 1})

      transaction =
        :transaction
        |> insert()
        |> with_block(consensus_block_1)

      for _ <- 0..10 do
        insert(:token_transfer,
          token_ids: [id],
          token_type: "ERC-721",
          transaction: transaction,
          token_contract_address: tt.token_contract_address,
          block_number: consensus_block_1.number,
          block: consensus_block_1
        )
      end

      tt_1 =
        insert(:token_transfer,
          token_ids: [id],
          token_type: "ERC-721",
          transaction: transaction,
          token_contract_address: tt.token_contract_address,
          block_number: consensus_block_1.number,
          block: consensus_block_1
        )

      %{hash: hash_2} = params_for(:block, consensus: true, miner_hash: miner_hash)
      consensus_block_2 = insert(:block, %{hash: hash_2, number: block_number - 2})

      for _ <- 0..10 do
        transaction =
          :transaction
          |> insert()
          |> with_block(consensus_block_2)

        insert(:token_transfer,
          token_ids: [id],
          token_type: "ERC-721",
          transaction: transaction,
          token_contract_address: tt.token_contract_address,
          block_number: consensus_block_2.number,
          block: consensus_block_2
        )
      end

      instance =
        insert(:token_instance,
          token_contract_address_hash: token_address.hash,
          token_id: id,
          owner_updated_at_block: tt.block_number,
          owner_updated_at_log_index: tt.log_index,
          owner_address_hash: insert(:address).hash
        )

      block_params =
        params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: false)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]
      error = instance.error
      block_number = tt_1.block_number
      log_index = tt_1.log_index
      owner_address_hash = tt_1.to_address_hash
      token_address_hash = token_address.hash

      assert {:ok,
              %{
                update_token_instances_owner: [
                  %Explorer.Chain.Token.Instance{
                    token_id: ^id,
                    error: ^error,
                    owner_updated_at_block: ^block_number,
                    owner_updated_at_log_index: ^log_index,
                    owner_address_hash: ^owner_address_hash,
                    token_contract_address_hash: ^token_address_hash
                  }
                ]
              }} = Multi.new() |> Blocks.run(changes_list, options) |> Repo.transaction()
    end

    test "change instance owner if there was no more token transfers",
         %{consensus_block: %{hash: block_hash, miner_hash: miner_hash, number: block_number}, options: options} do
      block_number = block_number + 1
      consensus_block = insert(:block, %{hash: block_hash, number: block_number})

      transaction =
        :transaction
        |> insert()
        |> with_block(consensus_block)

      token_address = insert(:contract_address)
      insert(:token, contract_address: token_address, type: "ERC-721")
      id = Decimal.new(1)

      tt =
        insert(:token_transfer,
          token_ids: [id],
          token_type: "ERC-721",
          transaction: transaction,
          token_contract_address: token_address,
          block_number: block_number,
          block: consensus_block
        )

      instance =
        insert(:token_instance,
          token_contract_address_hash: token_address.hash,
          token_id: id,
          owner_updated_at_block: tt.block_number,
          owner_updated_at_log_index: tt.log_index,
          owner_address_hash: insert(:address).hash
        )

      block_params =
        params_for(:block, hash: block_hash, miner_hash: miner_hash, number: block_number, consensus: false)

      %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)
      changes_list = [block_changes]
      error = instance.error
      owner_address_hash = tt.from_address_hash
      token_address_hash = token_address.hash

      assert {:ok,
              %{
                update_token_instances_owner: [
                  %Explorer.Chain.Token.Instance{
                    token_id: ^id,
                    error: ^error,
                    owner_updated_at_block: -1,
                    owner_updated_at_log_index: -1,
                    owner_address_hash: ^owner_address_hash,
                    token_contract_address_hash: ^token_address_hash
                  }
                ]
              }} = Multi.new() |> Blocks.run(changes_list, options) |> Repo.transaction()
    end

    if @chain_type == :celo do
      test "removes celo epoch rewards and sets fetched? = false when starting block loses consensus", %{
        consensus_block: %{miner_hash: miner_hash} = parent_block,
        options: options
      } do
        start_processing_block = insert(:block, number: 1, consensus: true, parent_hash: parent_block.hash)
        end_processing_block = insert(:block, number: 2, consensus: true, parent_hash: start_processing_block.hash)
        address = insert(:address)

        epoch = %{
          number: 1,
          start_processing_block_hash: start_processing_block.hash,
          end_processing_block_hash: end_processing_block.hash,
          fetched?: true
        }

        election_reward = %{
          epoch_number: epoch.number,
          account_address_hash: address.hash,
          amount: 100,
          associated_account_address_hash: address.hash,
          type: :validator
        }

        distribution = %{
          epoch_number: epoch.number,
          community_transfer_log_index: 1
        }

        {:ok, _imported} =
          Chain.import(%{
            celo_epochs: %{params: [epoch]},
            celo_election_rewards: %{params: [election_reward]},
            celo_epoch_rewards: %{params: [distribution]}
          })

        assert Repo.get_by(Explorer.Chain.Celo.Epoch, number: epoch.number)
        assert Repo.get_by(Explorer.Chain.Celo.EpochReward, epoch_number: epoch.number)
        assert Repo.get_by(Explorer.Chain.Celo.ElectionReward, epoch_number: epoch.number)

        block_params =
          params_for(:block,
            number: start_processing_block.number,
            miner_hash: miner_hash,
            parent_hash: parent_block.hash
          )

        start_processing_block_hash = start_processing_block.hash
        start_processing_block_number = start_processing_block.number
        end_processing_block_hash = end_processing_block.hash
        end_processing_block_number = end_processing_block.number

        assert {:ok,
                %{
                  celo_delete_epoch_rewards: [
                    %Explorer.Chain.Celo.Epoch{
                      number: 1,
                      fetched?: false,
                      start_processing_block_hash: ^start_processing_block_hash,
                      end_processing_block_hash: ^end_processing_block_hash
                    }
                  ],
                  lose_consensus: [
                    {^start_processing_block_number, ^start_processing_block_hash},
                    {^end_processing_block_number, ^end_processing_block_hash}
                  ]
                }} = insert_block(block_params, options)

        assert Repo.get_by(Explorer.Chain.Celo.Epoch, number: epoch.number).fetched? == false
        assert Repo.get_by(Explorer.Chain.Celo.EpochReward, epoch_number: epoch.number) == nil
        assert Repo.get_by(Explorer.Chain.Celo.ElectionReward, epoch_number: epoch.number) == nil
      end

      test "removes celo epoch rewards and sets fetched? = false when ending block loses consensus", %{
        consensus_block: %{miner_hash: miner_hash},
        options: options
      } do
        start_processing_block = insert(:block, number: 0, consensus: true)
        intermediate_block = insert(:block, number: 1, consensus: true)
        end_processing_block = insert(:block, number: 2, consensus: true, parent_hash: intermediate_block.hash)
        address = insert(:address)

        epoch = %{
          number: 1,
          start_processing_block_hash: start_processing_block.hash,
          end_processing_block_hash: end_processing_block.hash,
          fetched?: true
        }

        election_reward = %{
          epoch_number: epoch.number,
          account_address_hash: address.hash,
          amount: 100,
          associated_account_address_hash: address.hash,
          type: :validator
        }

        distribution = %{
          epoch_number: epoch.number,
          community_transfer_log_index: 1
        }

        {:ok, _imported} =
          Chain.import(%{
            celo_epochs: %{params: [epoch]},
            celo_election_rewards: %{params: [election_reward]},
            celo_epoch_rewards: %{params: [distribution]}
          })

        assert Repo.get_by(Explorer.Chain.Celo.Epoch, number: epoch.number)
        assert Repo.get_by(Explorer.Chain.Celo.EpochReward, epoch_number: epoch.number)
        assert Repo.get_by(Explorer.Chain.Celo.ElectionReward, epoch_number: epoch.number)

        block_params =
          params_for(:block,
            number: end_processing_block.number,
            miner_hash: miner_hash,
            parent_hash: intermediate_block.hash
          )

        start_processing_block_hash = start_processing_block.hash
        end_processing_block_hash = end_processing_block.hash
        end_processing_block_number = end_processing_block.number

        assert {:ok,
                %{
                  celo_delete_epoch_rewards: [
                    %Explorer.Chain.Celo.Epoch{
                      number: 1,
                      fetched?: false,
                      start_processing_block_hash: ^start_processing_block_hash,
                      end_processing_block_hash: ^end_processing_block_hash
                    }
                  ],
                  lose_consensus: [
                    {^end_processing_block_number, ^end_processing_block_hash}
                  ]
                }} = insert_block(block_params, options)

        assert Repo.get_by(Explorer.Chain.Celo.Epoch, number: epoch.number).fetched? == false
        assert Repo.get_by(Explorer.Chain.Celo.EpochReward, epoch_number: epoch.number) == nil
        assert Repo.get_by(Explorer.Chain.Celo.ElectionReward, epoch_number: epoch.number) == nil
      end
    end
  end

  describe "lose_consensus/5" do
    test "loses consensus only for consensus=true blocks" do
      insert(:block, consensus: true, number: 0)
      insert(:block, consensus: true, number: 1)
      insert(:block, consensus: false, number: 2)

      new_block0 = params_for(:block, miner_hash: insert(:address).hash, number: 0)
      new_block1 = params_for(:block, miner_hash: insert(:address).hash, parent_hash: new_block0.hash, number: 1)

      %Ecto.Changeset{valid?: true, changes: new_block1_changes} = Block.changeset(%Block{}, new_block1)

      opts = %{
        timeout: 60_000,
        timestamps: %{updated_at: DateTime.utc_now()}
      }

      assert {:ok, [{0, _}, {1, _}]} = Blocks.process_blocks_consensus([new_block1_changes], Repo, opts)
    end
  end

  defp insert_block(block_params, options) do
    %Ecto.Changeset{valid?: true, changes: block_changes} = Block.changeset(%Block{}, block_params)

    Multi.new()
    |> Blocks.run([block_changes], options)
    |> Repo.transaction()
  end

  defp transaction_params_with_block(transaction_params, block_params) do
    params_for(:transaction, transaction_params)
    |> Map.merge(%{
      block_hash: block_params.hash,
      block_number: block_params.number,
      cumulative_gas_used: 50_000,
      error: nil,
      gas_used: 50_000,
      index: 0,
      from_address_hash: insert(:address).hash
    })
  end

  defp insert_transaction(transaction_params, options) do
    %Ecto.Changeset{valid?: true, changes: transaction_changes} =
      Transaction.changeset(%Transaction{}, transaction_params)

    Multi.new()
    |> Transactions.run([transaction_changes], options)
    |> Repo.transaction()
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
         %{hash: block_hash, miner_hash: miner_hash, number: block_number},
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
