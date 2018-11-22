defmodule Explorer.Chain.LogTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Log

  doctest Log

  describe "changeset/2" do
    test "accepts valid attributes" do
      params = params_for(:log, address_hash: build(:address).hash, transaction_hash: build(:transaction).hash)

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
          transaction_hash: build(:transaction).hash
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

      assert Log.decode(log, transaction) == {:error, :contract_not_verified}
    end

    test "that a contract call transaction that has a verified contract returns the decoded input data" do
      smart_contract =
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
          ]
        )

      topic1 = "0x" <> Base.encode16(:keccakf1600.hash(:sha3_256, "WantsPets(string,uint256,bool)"), case: :lower)
      topic2 = "0x" <> Base.encode16(:keccakf1600.hash(:sha3_256, "bob"), case: :lower)
      topic3 = "0x0000000000000000000000000000000000000000000000000000000000000001"
      data = "0x0000000000000000000000000000000000000000000000000000000000000000"

      to_address = insert(:address, smart_contract: smart_contract)

      transaction =
        :transaction_to_verified_contract
        |> insert(to_address: to_address)
        |> Repo.preload(to_address: :smart_contract)

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
  end
end
