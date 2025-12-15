defmodule Explorer.Chain.FheContractCheckerTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{Address, FheContractChecker, Hash}
  alias Explorer.Tags.{AddressTag, AddressToTag}
  alias Explorer.Repo

  setup :verify_on_exit!
  setup :set_mox_global

  describe "is_fhe_contract?/1" do
    test "returns true for FHE contract with non-zero protocol ID" do
      address_hash = build(:address).hash

      # Mock RPC response with non-zero protocol ID
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000001"}
      end)

      assert {:ok, true} = FheContractChecker.is_fhe_contract?(address_hash)
    end

    test "returns false for non-FHE contract with zero protocol ID" do
      address_hash = build(:address).hash

      # Mock RPC response with zero protocol ID
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)

      assert {:ok, false} = FheContractChecker.is_fhe_contract?(address_hash)
    end

    test "returns false for RPC error" do
      address_hash = build(:address).hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:error, :timeout}
      end)

      assert {:ok, false} = FheContractChecker.is_fhe_contract?(address_hash)
    end

    test "returns false for invalid response format" do
      address_hash = build(:address).hash

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, []}
      end)

      assert {:ok, false} = FheContractChecker.is_fhe_contract?(address_hash)
    end

    test "handles string address hash" do
      address_string = "0x" <> String.duplicate("1", 40)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)

      assert {:ok, false} = FheContractChecker.is_fhe_contract?(address_string)
    end

    test "returns error for invalid address string" do
      assert {:error, :invalid_hash} = FheContractChecker.is_fhe_contract?("invalid")
    end
  end

  describe "already_checked?/2" do
    test "returns true when address is already tagged as FHE" do
      address = insert(:address)
      tag = insert(:address_tag, label: "fhe", display_name: "FHE")
      insert(:address_to_tag, tag: tag, address: address)

      assert true == FheContractChecker.already_checked?(address.hash, [])
    end

    test "returns false when address is not tagged" do
      address = insert(:address)
      _tag = insert(:address_tag, label: "fhe", display_name: "FHE")

      assert false == FheContractChecker.already_checked?(address.hash, [])
    end

    test "returns false when FHE tag does not exist" do
      address = insert(:address)

      assert false == FheContractChecker.already_checked?(address.hash, [])
    end
  end

  describe "check_and_save_fhe_status/2" do
    test "saves FHE tag when contract is FHE" do
      address = insert(:address, contract_code: "0x6080604052")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000001"}
      end)

      assert :ok = FheContractChecker.check_and_save_fhe_status(address.hash, [])

      # Verify tag was created
      tag = Repo.get_by(AddressTag, label: "fhe")
      assert tag != nil
      assert tag.display_name == "FHE"

      # Verify address is tagged
      tag_id = AddressTag.get_id_by_label("fhe")
      assert Repo.exists?(
               from(att in AddressToTag,
                 where: att.address_hash == ^Hash.to_string(address.hash) and att.tag_id == ^tag_id
               )
             )
    end

    test "returns :ok when contract is not FHE" do
      address = insert(:address, contract_code: "0x6080604052")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)

      assert :ok = FheContractChecker.check_and_save_fhe_status(address.hash, [])
    end

    test "returns :already_checked when address is already tagged" do
      address = insert(:address, contract_code: "0x6080604052")
      tag = insert(:address_tag, label: "fhe", display_name: "FHE")
      insert(:address_to_tag, tag: tag, address: address)

      assert :already_checked = FheContractChecker.check_and_save_fhe_status(address.hash, [])
    end

    test "returns :empty when address is not a contract" do
      address = insert(:address, contract_code: nil)

      assert :empty = FheContractChecker.check_and_save_fhe_status(address.hash, [])
    end

    test "returns :empty when address_hash is nil" do
      assert :empty = FheContractChecker.check_and_save_fhe_status(nil, [])
    end

    test "returns :ok when RPC call fails (treats as non-FHE to avoid retry loops)" do
      address = insert(:address, contract_code: "0x6080604052")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _request, _options ->
        {:error, :timeout}
      end)

      # The implementation treats RPC errors as "not FHE" (returns :ok) to avoid retry loops
      assert :ok = FheContractChecker.check_and_save_fhe_status(address.hash, [])
    end
  end

end

