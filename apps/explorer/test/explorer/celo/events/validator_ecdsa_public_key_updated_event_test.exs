defmodule Explorer.Celo.Events.ValidatorEcdsaPublicKeyUpdatedEvent do
  use Explorer.DataCase, async: true

  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Chain.{Address, Block, Log}
  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Celo.ContractEvents.Validators.ValidatorEcdsaPublicKeyUpdatedEvent

  describe "encoding / decoding" do
    test "should handle encoding of bytes data that includes invalid utf8 codepoints" do
      %Explorer.Chain.Block{number: block_number, hash: hash} = insert(:block)
      %Explorer.Chain.CeloCoreContract{address_hash: address_hash} = insert(:core_contract)

      # values taken from production environment and causing an error due to "invalid byte 0x95" in ecdsa_public_key
      # https://github.com/celo-org/data-services/issues/231

      # below log_data includes an event parameter that should decode to the following binary term
      expected_public_key =
        <<27, 149, 173, 3, 199, 243, 248, 121, 204, 177, 130, 75, 29, 132, 235, 113, 78, 246, 213, 171, 152, 216, 246,
          254, 154, 199, 124, 145, 7, 153, 92, 105, 76, 239, 244, 76, 75, 6, 166, 156, 19, 179, 255, 236, 186, 85, 16,
          198, 10, 147, 57, 94, 183, 88, 171, 28, 12, 210, 179, 85, 248, 221, 82, 36>>

      log_data =
        %{
          "address" => address_hash |> to_string(),
          "topics" => [
            "0x213377eec2c15b21fa7abcbb0cb87a67e893cdb94a2564aa4bb4d380869473c8",
            "0x0000000000000000000000002bdc5ccda08a7f821ae0df72b5fda60cd58d6353"
          ],
          "data" =>
            "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000401b95ad03c7f3f879ccb1824b1d84eb714ef6d5ab98d8f6fe9ac77c9107995c694ceff44c4b06a69c13b3ffecba5510c60a93395eb758ab1c0cd2b355f8dd5224",
          "blockNumber" => block_number,
          "transactionHash" => nil,
          "transactionIndex" => nil,
          "blockHash" => hash |> to_string(),
          "logIndex" => "0xc",
          "removed" => false
        }
        |> EthereumJSONRPC.Log.to_elixir()
        |> EthereumJSONRPC.Log.elixir_to_params()

      changeset_params =
        EventMap.rpc_to_event_params([log_data])
        |> List.first()
        |> Map.put(:updated_at, Timex.now())
        |> Map.put(:inserted_at, Timex.now())

      # insert into db and assert that public key is inserted as valid json
      {1, _} = Explorer.Repo.insert_all(CeloContractEvent, [changeset_params])

      # retrieve from db
      [event] = ValidatorEcdsaPublicKeyUpdatedEvent.query() |> EventMap.query_all()

      assert(event.ecdsa_public_key |> :erlang.list_to_binary() == expected_public_key)
    end
  end
end
