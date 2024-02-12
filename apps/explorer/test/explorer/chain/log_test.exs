defmodule Explorer.Chain.LogTest do
  use Explorer.DataCase

  import Mox

  alias Ecto.Changeset
  alias Explorer.Chain.{Log, SmartContract}
  alias Explorer.Repo

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end

  setup :set_mox_from_context

  doctest Log

  setup :verify_on_exit!

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
          first_topic: @first_topic_hex_string_1,
          transaction_hash: build(:transaction).hash,
          block_hash: build(:block).hash
        )

      result = Log.changeset(%Log{}, params)

      assert result.valid? == true
      assert result.changes.first_topic == topic(@first_topic_hex_string_1)
    end

    test "assigns optional attributes" do
      params = Map.put(params_for(:log), :first_topic, topic(@first_topic_hex_string_1))
      changeset = Log.changeset(%Log{}, params)
      assert changeset.changes.first_topic === topic(@first_topic_hex_string_1)
    end
  end

  describe "decode/2" do
    test "that a contract call transaction that has no verified contract returns a commensurate error" do
      transaction =
        :transaction
        |> insert(to_address: insert(:contract_address))
        |> Repo.preload(to_address: :smart_contract)

      log = insert(:log, transaction: transaction)

      assert {{:error, :could_not_decode}, _, _} = Log.decode(log, transaction, [], false)
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
          first_topic: topic(topic1),
          second_topic: topic(topic2),
          third_topic: topic(topic3),
          fourth_topic: nil,
          data: data
        )

      request_zero_implementations()

      assert {{:ok, "eb9b3c4c", "WantsPets(string indexed _from_human, uint256 _number, bool indexed _belly)",
               [
                 {"_from_human", "string", true,
                  {:dynamic,
                   <<56, 228, 122, 123, 113, 157, 206, 99, 102, 42, 234, 244, 52, 64, 50, 111, 85, 27, 138, 126, 225,
                     152, 206, 227, 92, 181, 213, 23, 242, 210, 150, 162>>}},
                 {"_number", "uint256", false, 0},
                 {"_belly", "bool", true, true}
               ]}, _, _} = Log.decode(log, transaction, [], false)
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
          first_topic: topic(topic1),
          second_topic: topic(topic2),
          third_topic: topic(topic3),
          fourth_topic: nil,
          data: data
        )

      assert {{:error, :contract_not_verified,
               [
                 {:ok, "eb9b3c4c", "WantsPets(string indexed _from_human, uint256 _number, bool indexed _belly)",
                  [
                    {"_from_human", "string", true,
                     {:dynamic,
                      <<56, 228, 122, 123, 113, 157, 206, 99, 102, 42, 234, 244, 52, 64, 50, 111, 85, 27, 138, 126, 225,
                        152, 206, 227, 92, 181, 213, 23, 242, 210, 150, 162>>}},
                    {"_number", "uint256", false, 0},
                    {"_belly", "bool", true, true}
                  ]}
               ]}, _, _} = Log.decode(log, transaction, [], false)
    end
  end

  def request_zero_implementations do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
    |> expect(:json_rpc, fn %{
                              id: 0,
                              method: "eth_getStorageAt",
                              params: [
                                _,
                                "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7",
                                "latest"
                              ]
                            },
                            _options ->
      {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
    end)
  end
end
