defmodule Indexer.Celo.TrackedEventSupport do
  import Explorer.Factory
  alias Explorer.Chain.{Log, SmartContract}
  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Repo
  import Mox

  def create_smart_contract do
    contract_abi =
      File.read!("../explorer/test/explorer/chain/celo/lockedgoldabi.json")
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
      abi: contract_code_info.abi,
      contract_code_md5: "123"
    }
    |> insert()
  end

  # example abi above is locked gold contract, valid topics need to be used for ContractEventTracking to extract
  # the event abi from the full contract abi
  def gold_unlocked_topic, do: "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588"
  def gold_relocked_topic, do: "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0"
  def slasher_whitelist_added_topic, do: "0x92a16cb9e1846d175c3007fc61953d186452c9ea1aa34183eb4b7f88cd3f07bb"

  def add_trackings(event_topics, smart_contract \\ nil)

  def add_trackings(event_topics, nil) do
    smart_contract = create_smart_contract()
    add_trackings(event_topics, smart_contract)
  end

  def add_trackings(event_topics, smart_contract) do
    event_topics
    |> Enum.each(fn topic ->
      # creation of event will read blockchain status to test if this is part of a proxy contract implementation
      # mocking error reponse to simulate what happens when accessing storage address of non proxy contract
      EthereumJSONRPC.Mox |> expect(:json_rpc, fn _json, _options -> {:error, []} end)

      {:ok, _tracking} =
        smart_contract
        |> ContractEventTracking.from_event_topic(topic)
        |> Repo.insert()
    end)

    smart_contract
  end

  def gold_relocked_logs(address_hash) do
    [
      {"0x00000000000000000000000000000000000000000000001FBF29AF3F33C638A8",
       "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0",
       "0x000000000000000000000000adef8d4fa068e430cae0601b45ae662caa4e1000"},
      {"0x00000000000000000000000000000000000000000000000998B2131818B05748",
       "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0",
       "0x0000000000000000000000002879bfd5e7c4ef331384e908aaa3bd3014b703fa"},
      {"0x00000000000000000000000000000000000000000000002B8959185B12F21786",
       "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0",
       "0x00000000000000000000000095508d0e7b07010ab2c091236f9a170366e6b415"},
      {"0x000000000000000000000000000000000000000000000001A055690D9DB80000",
       "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0",
       "0x000000000000000000000000fc80cca610664a2d0fff392b6e2e96d4a8075f93"},
      {"0x00000000000000000000000000000000000000000000005DDBF0E8305EE6B3AB",
       "0xa823fc38a01c2f76d7057a79bb5c317710f26f7dbdea78634598d5519d0f7cb0",
       "0x0000000000000000000000002879bfd5e7c4ef331384e908aaa3bd3014b703fa"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{data, first_topic, second_topic}, index} ->
      %Log{
        first_topic: first_topic,
        second_topic: second_topic,
        data: data |> String.downcase(),
        transaction_hash: nil,
        address_hash: address_hash,
        block_number: 77,
        index: index
      }
    end)
  end
end
