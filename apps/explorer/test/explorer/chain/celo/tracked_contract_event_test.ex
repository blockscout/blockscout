defmodule Explorer.Chain.Celo.TrackedContractEventTest do
  use Explorer.DataCase
  import Explorer.Factory

  alias Explorer.Chain.Celo.{ContractEventTracking, TrackedContractEvent}
  alias Explorer.Chain.{Log, SmartContract}

  describe "TrackedContractEvent" do
    def create_smart_contract do
      contract_abi =
        File.read!("./test/explorer/chain/celo/lockedgoldabi.json")
        |> Jason.decode!()

      contract_code_info = %{
        bytecode:
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820f65a3adc1cfb055013d1dc37d0fe98676e2a5963677fa7541a10386d163446680029",
        tx_input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820853a985d0a4b20246785fc2f0357c202faa3db289980a48737180f358f9ddc3c0029",
        name: "ContractEventTrackingTestContract",
        source_code: """
        //code isn't important for these tests
        """,
        abi: contract_abi,
        version: "v0.4.24+commit.e67f0147",
        optimized: false
      }

      %SmartContract{
        address_hash: insert(:address, contract_code: contract_code_info.bytecode, verified: true).hash,
        compiler_version: contract_code_info.version,
        name: contract_code_info.name,
        contract_source_code: contract_code_info.source_code,
        optimization: contract_code_info.optimized,
        abi: contract_code_info.abi
      }
      |> insert()
    end

    @gold_unlocked_topic "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588"

    def create_event_tracking do
      smart_contract = create_smart_contract()

      {:ok, tracking} =
        smart_contract
        |> ContractEventTracking.from_event_topic(@gold_unlocked_topic)
        |> Repo.insert()

      tracking
    end

    test "should insert valid event" do
      event_tracking =
        create_event_tracking()
        |> Repo.preload(:address)

      source_log =
        build(
          :log,
          %{
            first_topic: @gold_unlocked_topic,
            address: event_tracking.address,
            block_number: 7777,
            index: 55
          }
        )
        |> insert()

      event_params = %{"account" => "0xtestacacount", "value" => 44444, "available" => 55555}

      event_changeset = TrackedContractEvent.from(%{params: event_params}, source_log, event_tracking)

      assert event_changeset.valid?

      {:ok, _event} = Repo.insert(event_changeset)
    end
  end
end
