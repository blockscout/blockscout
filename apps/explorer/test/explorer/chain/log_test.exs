defmodule Explorer.Chain.LogTest do
  use Explorer.DataCase

  import Mox

  alias Ecto.Changeset
  alias Explorer.Chain.{Log, SmartContract}
  alias Explorer.Repo

  doctest Log

  describe "changeset/2" do
    test "accepts valid attributes" do
      params =
        params_for(:log,
          address_hash: build(:address).hash,
          transaction_hash: build(:transaction).hash,
          block_hash: build(:block).hash
        )

      assert %Changeset{valid?: true} = Log.changeset(%Log{}, params)
    end

    test "rejects missing attributes" do
      params = params_for(:log, data: nil)
      changeset = Log.changeset(%Log{}, params)
      refute changeset.valid?
    end

    test "accepts optional attributes" do
      params =
        params_for(
          :log,
          address_hash: build(:address).hash,
          first_topic: "ham",
          transaction_hash: build(:transaction).hash,
          block_hash: build(:block).hash
        )

      assert %Changeset{changes: %{first_topic: "ham"}, valid?: true} = Log.changeset(%Log{}, params)
    end

    test "assigns optional attributes" do
      params = Map.put(params_for(:log), :first_topic, "ham")
      changeset = Log.changeset(%Log{}, params)
      assert changeset.changes.first_topic === "ham"
    end
  end

  describe "decode/2" do
    test "that a contract call transaction that has no verified contract returns a commensurate error" do
      transaction =
        :transaction
        |> insert(to_address: insert(:contract_address))
        |> Repo.preload(to_address: :smart_contract)

      log = insert(:log, transaction: transaction)

      assert Log.decode(log, transaction) == {:error, :could_not_decode}
    end

    test "that a contract call transaction that has a verified contract returns the decoded input data" do
      to_address = insert(:address, contract_code: "0x")

      insert(:smart_contract,
        abi: [
          %{
            "anonymous" => false,
            "inputs" => [
              %{"indexed" => true, "name" => "_from_human", "type" => "string"},
              %{"indexed" => false, "name" => "_number", "type" => "uint256"},
              %{"indexed" => true, "name" => "_belly", "type" => "bool"}
            ],
            "name" => "WantsPets",
            "type" => "event"
          }
        ],
        address_hash: to_address.hash,
        contract_code_md5: "123"
      )

      topic1_bytes = ExKeccak.hash_256("WantsPets(string,uint256,bool)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      topic2_bytes = ExKeccak.hash_256("bob")
      topic2 = "0x" <> Base.encode16(topic2_bytes, case: :lower)
      topic3 = "0x0000000000000000000000000000000000000000000000000000000000000001"
      data = "0x0000000000000000000000000000000000000000000000000000000000000000"

      transaction =
        :transaction_to_verified_contract
        |> insert(to_address: to_address)
        |> Repo.preload(to_address: :smart_contract)

      log =
        insert(:log,
          address: to_address,
          transaction: transaction,
          first_topic: topic1,
          second_topic: topic2,
          third_topic: topic3,
          fourth_topic: nil,
          data: data
        )

      blockchain_get_code_mock()

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )

      assert Log.decode(log, transaction) ==
               {:ok, "eb9b3c4c", "WantsPets(string indexed _from_human, uint256 _number, bool indexed _belly)",
                [
                  {"_from_human", "string", true,
                   {:dynamic,
                    <<56, 228, 122, 123, 113, 157, 206, 99, 102, 42, 234, 244, 52, 64, 50, 111, 85, 27, 138, 126, 225,
                      152, 206, 227, 92, 181, 213, 23, 242, 210, 150, 162>>}},
                  {"_number", "uint256", false, 0},
                  {"_belly", "bool", true, true}
                ]}
    end

    test "finds decoding candidates" do
      params =
        params_for(:smart_contract, %{
          abi: [
            %{
              "anonymous" => false,
              "inputs" => [
                %{"indexed" => true, "name" => "_from_human", "type" => "string"},
                %{"indexed" => false, "name" => "_number", "type" => "uint256"},
                %{"indexed" => true, "name" => "_belly", "type" => "bool"}
              ],
              "name" => "WantsPets",
              "type" => "event"
            }
          ]
        })

      # changeset has a callback to insert contract methods
      %SmartContract{}
      |> SmartContract.changeset(params)
      |> Repo.insert!()

      topic1_bytes = ExKeccak.hash_256("WantsPets(string,uint256,bool)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      topic2_bytes = ExKeccak.hash_256("bob")
      topic2 = "0x" <> Base.encode16(topic2_bytes, case: :lower)
      topic3 = "0x0000000000000000000000000000000000000000000000000000000000000001"
      data = "0x0000000000000000000000000000000000000000000000000000000000000000"

      transaction = insert(:transaction)

      log =
        insert(:log,
          transaction: transaction,
          first_topic: topic1,
          second_topic: topic2,
          third_topic: topic3,
          fourth_topic: nil,
          data: data
        )

      assert Log.decode(log, transaction) ==
               {:error, :contract_not_verified,
                [
                  {:ok, "eb9b3c4c", "WantsPets(string indexed _from_human, uint256 _number, bool indexed _belly)",
                   [
                     {"_from_human", "string", true,
                      {:dynamic,
                       <<56, 228, 122, 123, 113, 157, 206, 99, 102, 42, 234, 244, 52, 64, 50, 111, 85, 27, 138, 126,
                         225, 152, 206, 227, 92, 181, 213, 23, 242, 210, 150, 162>>}},
                     {"_number", "uint256", false, 0},
                     {"_belly", "bool", true, true}
                   ]}
                ]}
    end
  end

  defp blockchain_get_code_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_getCode", params: [_, _]}], _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x0"}]}
      end
    )
  end
end
