defmodule Indexer.Fetcher.CeloElectionRewardsTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Ecto.Query
  import Explorer.Celo.CacheHelper
  import Explorer.Factory
  import Mox

  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent
  alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  alias Explorer.Chain.{Address, Block, CeloElectionRewards, Wei}
  alias Indexer.Fetcher.CeloElectionRewards, as: CeloElectionRewardsFetcher

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    # Need to always mock to allow consensus switches to happen on demand and protect from them happening when we don't
    # want them to.
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPPC.Parity
      ]
    }
  end

  describe "async_fetch/1" do
    setup [:save_voter_contract_events_and_start_fetcher]

    test "with consensus block without reward", context do
      CeloElectionRewardsFetcher.async_fetch([
        %{
          block_number: context.last_block_in_epoch_number,
          block_timestamp: DateTime.utc_now()
        }
      ])

      wait_for_results(fn ->
        reward = Repo.one!(from(rewards in CeloElectionRewards))

        {:ok, amount_in_wei} = Wei.cast(4_503_599_627_369_846)
        assert reward.reward_type == "voter"
        assert reward.block_number == context.last_block_in_epoch_number
        assert reward.amount == amount_in_wei
      end)

      # Terminates the process so it finishes all Ecto processes.
      GenServer.stop(context.pid)
    end
  end

  describe "init/2" do
    test "buffers unindexed epoch blocks", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_number: block.number)

      assert CeloElectionRewardsFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == [%{block_number: block.number, block_timestamp: block.timestamp}]
    end

    test "does not buffer blocks with fetched election rewards", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_number: block.number, election_rewards: false)

      assert CeloElectionRewardsFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "get_voter_rewards, when voter rewards are passed" do
    test "it returns the argument" do
      argument = %{
        voter_rewards: "does not matter"
      }

      assert CeloElectionRewardsFetcher.get_voter_rewards(argument) == argument
    end
  end

  describe "get_validator_and_group_rewards, when no validator and group rewards are passed" do
    setup [:save_validator_and_group_contract_events]

    test "it fetches them from the db for a block", context do
      assert CeloElectionRewardsFetcher.get_validator_and_group_rewards(%{
               block_number: context.block_number,
               block_timestamp: context.block_timestamp
             }) == %{
               block_number: context.block_number,
               block_timestamp: context.block_timestamp,
               validator_rewards: [
                 %{
                   account_hash: context.validator_1_hash,
                   amount: 100_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 },
                 %{
                   account_hash: context.validator_2_hash,
                   amount: 200_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 }
               ],
               group_rewards: [
                 %{
                   account_hash: context.group_hash,
                   amount: 300_000,
                   associated_account_hash: context.validator_1_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "group"
                 },
                 %{
                   account_hash: context.group_hash,
                   amount: 300_000,
                   associated_account_hash: context.validator_2_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "group"
                 }
               ]
             }
    end
  end

  describe "get_validator_and_group_rewards, when only validator rewards are passed" do
    setup [:save_validator_and_group_contract_events]

    test "it fetches them from the db for a block", context do
      assert CeloElectionRewardsFetcher.get_validator_and_group_rewards(%{
               block_number: context.block_number,
               block_timestamp: context.block_timestamp,
               validator_rewards: [
                 %{
                   account_hash: context.validator_1_hash,
                   amount: 100_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 },
                 %{
                   account_hash: context.validator_2_hash,
                   amount: 200_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 }
               ]
             }) == %{
               block_number: context.block_number,
               block_timestamp: context.block_timestamp,
               group_rewards: [
                 %{
                   account_hash: context.group_hash,
                   amount: 300_000,
                   associated_account_hash: context.validator_1_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "group"
                 },
                 %{
                   account_hash: context.group_hash,
                   amount: 300_000,
                   associated_account_hash: context.validator_2_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "group"
                 }
               ],
               validator_rewards: [
                 %{
                   account_hash: context.validator_1_hash,
                   amount: 100_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 },
                 %{
                   account_hash: context.validator_2_hash,
                   amount: 200_000,
                   associated_account_hash: context.group_hash,
                   block_number: context.block_number,
                   block_timestamp: context.block_timestamp,
                   reward_type: "validator"
                 }
               ]
             }
    end
  end

  describe "get_validator_and_group_rewards, when validator and group rewards are passed" do
    test "it returns the argument" do
      argument = %{
        group_rewards: "does not",
        validator_rewards: "matter"
      }

      assert CeloElectionRewardsFetcher.get_validator_and_group_rewards(argument) == argument
    end
  end

  describe "import_items/1" do
    test "saves rewards" do
      %Address{hash: voter_hash} = insert(:address)
      %Address{hash: validator_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)

      %Block{number: block_number} = insert(:block, number: 10_679_040)
      insert(:celo_pending_epoch_operations, block_number: block_number)
      insert(:celo_account, address: group_hash)
      insert(:celo_account, address: validator_hash)

      input = %{
        block_number: block_number,
        voter_rewards: [
          %{
            account_hash: voter_hash,
            amount: 4_503_599_627_369_846,
            associated_account_hash: group_hash,
            block_number: block_number,
            block_timestamp: ~U[2022-05-10 14:18:54.093055Z],
            reward_type: "voter"
          }
        ],
        validator_rewards: [
          %{
            account_hash: validator_hash,
            amount: 4_503_599_627_369_846,
            associated_account_hash: group_hash,
            block_number: block_number,
            block_timestamp: ~U[2022-05-10 14:18:54.093055Z],
            reward_type: "validator"
          }
        ],
        group_rewards: [
          %{
            account_hash: group_hash,
            amount: 4_503_599_627_369_846,
            associated_account_hash: validator_hash,
            block_number: block_number,
            block_timestamp: ~U[2022-05-10 14:18:54.093055Z],
            reward_type: "group"
          }
        ]
      }

      assert CeloElectionRewardsFetcher.import_items(input) == :ok
    end

    test "with missing data removes rewards type" do
      %Block{number: block_number} = insert(:block, number: 10_679_040)

      assert CeloElectionRewardsFetcher.import_items(%{
               block_number: block_number,
               voter_rewards: [%{block_number: block_number}]
             }) == %{block_number: block_number}
    end
  end

  defp setup_mox() do
    set_test_addresses(%{
      "Election" => "0x8d6677192144292870907e3fa8a5527fe55a7ff6"
    })

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [
           %{
             id: getActiveVotesForGroupByAccount,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: _, to: _}, _]
           }
         ],
         _second_to_last_block_in_epoch_number_number ->
        {
          :ok,
          [
            %{
              id: getActiveVotesForGroupByAccount,
              jsonrpc: "2.0",
              result: "0x00000000000000000000000000000000000000000002bcd397c61e026fd24890"
            }
          ]
        }
      end
    )

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [
           %{
             id: getActiveVotesForGroupByAccount,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: _, to: _}, _]
           }
         ],
         _last_block_in_epoch_number_number ->
        {
          :ok,
          [
            %{
              id: getActiveVotesForGroupByAccount,
              jsonrpc: "2.0",
              result: "0x00000000000000000000000000000000000000000002bcd397d61e026fd24890"
            }
          ]
        }
      end
    )
  end

  defp save_validator_and_group_contract_events(context) do
    %Address{hash: validator_1_hash} = insert(:address)
    %Address{hash: validator_2_hash} = insert(:address)
    %Address{hash: group_hash} = insert(:address)
    %Explorer.Chain.CeloCoreContract{address_hash: contract_hash} = insert(:core_contract)

    %Block{number: block_number, timestamp: block_timestamp} = block = insert(:block, number: 10_679_040)

    log_1 = insert(:log, block: block, index: 1)
    log_2 = insert(:log, block: block, index: 2)
    insert(:celo_account, address: group_hash)

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        __block_number: block_number,
        __contract_address_hash: contract_hash,
        __log_index: log_1.index,
        validator: validator_1_hash,
        validator_payment: 100_000,
        group: group_hash,
        group_payment: 300_000
      }
    })

    insert(:contract_event, %{
      event: %ValidatorEpochPaymentDistributedEvent{
        __block_number: block_number,
        __contract_address_hash: contract_hash,
        __log_index: log_2.index,
        validator: validator_2_hash,
        validator_payment: 200_000,
        group: group_hash,
        group_payment: 300_000
      }
    })

    Map.merge(context, %{
      block_number: block_number,
      block_timestamp: block_timestamp,
      group_hash: group_hash,
      validator_1_hash: validator_1_hash,
      validator_2_hash: validator_2_hash
    })
  end

  defp save_voter_contract_events_and_start_fetcher(context) do
    pid =
      CeloElectionRewardsFetcher.Supervisor.Case.start_supervised!(
        json_rpc_named_arguments: context.json_rpc_named_arguments
      )

    %Address{hash: voter_hash} = insert(:address)
    %Address{hash: group_hash} = insert(:address)
    insert(:celo_account, address: group_hash)
    %Explorer.Chain.CeloCoreContract{address_hash: contract_hash} = insert(:core_contract)

    %Block{number: second_to_last_block_in_epoch_number} =
      second_to_last_block_in_epoch = insert(:block, number: 17_279)

    %Block{number: last_block_in_epoch_number} = insert(:block, number: 17_280)
    log = insert(:log, block: second_to_last_block_in_epoch)

    insert(:celo_pending_epoch_operations, block_number: last_block_in_epoch_number)

    insert(:contract_event, %{
      event: %ValidatorGroupVoteActivatedEvent{
        __block_number: second_to_last_block_in_epoch_number,
        __contract_address_hash: contract_hash,
        __log_index: log.index,
        account: voter_hash,
        group: group_hash,
        units: 10000,
        value: 650
      }
    })

    setup_mox()

    Map.merge(context, %{
      last_block_in_epoch_number: last_block_in_epoch_number,
      pid: pid
    })
  end
end
