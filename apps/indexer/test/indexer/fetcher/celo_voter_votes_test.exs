defmodule Indexer.Fetcher.CeloVoterVotesTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Ecto.Query
  import Explorer.Celo.CacheHelper
  import Explorer.Factory
  import Mox

  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent
  alias Explorer.Chain.{Address, Block, CeloVoterVotes, Hash}
  alias Indexer.Fetcher.CeloVoterVotes, as: CeloVoterVotesFetcher

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

  describe "init/2" do
    test "buffers unindexed epoch blocks", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash)

      assert CeloVoterVotesFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == [%{block_number: block.number, block_hash: block.hash}]
    end

    test "does not buffer blocks with fetched epoch rewards", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash, fetch_voter_votes: false)

      assert CeloVoterVotesFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "fetch_from_blockchain/1" do
    test "fetches validator group votes from blockchain" do
      account_1_hash = %Hash{
        byte_count: 20,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
      }

      account_2_hash = %Hash{
        byte_count: 20,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
      }

      group_1_hash = %Hash{
        byte_count: 20,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
      }

      group_2_hash = %Hash{
        byte_count: 20,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4>>
      }

      block_hash = %Hash{
        byte_count: 32,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
      }

      to_fetch = [
        %{
          account_hash: account_1_hash,
          block_number: 10_696_320,
          block_hash: block_hash,
          group_hash: group_1_hash
        },
        %{
          account_hash: account_2_hash,
          block_number: 10_696_320,
          block_hash: block_hash,
          group_hash: group_2_hash
        }
      ]

      setup_mox()

      result = Enum.map(to_fetch, &CeloVoterVotesFetcher.fetch_from_blockchain/1)

      assert result == [
               %{
                 account_hash: account_1_hash,
                 active_votes: 3_309_559_737_470_045_295_626_384,
                 block_number: 10_696_320,
                 block_hash: block_hash,
                 group_hash: group_1_hash
               },
               %{
                 account_hash: account_2_hash,
                 active_votes: 2_601_552_679_256_724_525_663_215,
                 block_number: 10_696_320,
                 block_hash: block_hash,
                 group_hash: group_2_hash
               }
             ]
    end
  end

  describe "import_items/1" do
    test "saves voter votes" do
      %Address{hash: voter_1_address_hash} = insert(:address)
      %Address{hash: voter_2_address_hash} = insert(:address)
      %Address{hash: group_address_hash} = insert(:address)

      %Block{hash: block_hash} = insert(:block, number: 10_679_040)
      insert(:celo_pending_epoch_operations, block_hash: block_hash)

      voter_votes = [
        %{
          account_hash: voter_1_address_hash,
          active_votes: 3_309_559_737_470_045_295_626_384,
          block_hash: block_hash,
          block_number: 10_696_320,
          group_hash: group_address_hash
        },
        %{
          account_hash: voter_2_address_hash,
          active_votes: 2_601_552_679_256_724_525_663_215,
          block_hash: block_hash,
          block_number: 10_696_320,
          group_hash: group_address_hash
        }
      ]

      CeloVoterVotesFetcher.import_items(voter_votes)
      assert count(CeloVoterVotes) == 2
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
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
         _ ->
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
         _ ->
        {
          :ok,
          [
            %{
              id: getActiveVotesForGroupByAccount,
              jsonrpc: "2.0",
              result: "0x0000000000000000000000000000000000000000000226e6740db72837e5c3ef"
            }
          ]
        }
      end
    )
  end
end
