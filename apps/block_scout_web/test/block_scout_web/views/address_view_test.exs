defmodule BlockScoutWeb.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.Data
  alias BlockScoutWeb.AddressView

  describe "contract?/1" do
    test "with a smart contract" do
      {:ok, code} = Data.cast("0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef")
      address = insert(:address, contract_code: code)
      assert AddressView.contract?(address)
    end

    test "with an account" do
      address = insert(:address, contract_code: nil)
      refute AddressView.contract?(address)
    end

    test "with nil address" do
      assert AddressView.contract?(nil)
    end
  end

  describe "display_address_hash/3" do
    test "for a pending contract creation to address" do
      transaction = insert(:transaction, to_address: nil, created_contract_address_hash: nil)
      assert AddressView.display_address_hash(nil, transaction, :to) == "Contract Address Pending"
    end

    test "for a non-contract to address not on address page" do
      transaction = insert(:transaction)
      rendered_string =
        nil
        |> AddressView.display_address_hash(transaction, :to)
        |> Phoenix.HTML.safe_to_string()
      assert rendered_string =~ "responsive_hash"
      assert rendered_string =~ "address_hash_link"
      refute rendered_string =~ "contract-address"
    end

    test "for a non-contract to address non matching address page" do
      transaction = insert(:transaction)
      rendered_string =
        :address
        |> insert()
        |> AddressView.display_address_hash(transaction, :to)
        |> Phoenix.HTML.safe_to_string()
      assert rendered_string =~ "responsive_hash"
      assert rendered_string =~ "address_hash_link"
      refute rendered_string =~ "contract-address"
    end

    test "for a non-contract to address matching address page" do
      transaction = insert(:transaction)
      rendered_string =
        transaction.to_address
        |> AddressView.display_address_hash(transaction, :to)
        |> Phoenix.HTML.safe_to_string()
      assert rendered_string =~ "responsive_hash"
      refute rendered_string =~ "address_hash_link"
      refute rendered_string =~ "contract-address"
    end
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      address = build(:address)
      assert {:ok, _} = Base.decode64(AddressView.qr_code(address))
    end
  end

  describe "smart_contract_verified?/1" do
    test "returns true when smart contract is verified" do
      smart_contract = insert(:smart_contract)
      address = insert(:address, smart_contract: smart_contract)

      assert AddressView.smart_contract_verified?(address)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      refute AddressView.smart_contract_verified?(address)
    end
  end

  describe "smart_contract_with_read_only_functions?/1" do
    test "returns true when abi has read only functions" do
      smart_contract =
        insert(
          :smart_contract,
          abi: [
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ]
        )

      address = insert(:address, smart_contract: smart_contract)

      assert AddressView.smart_contract_with_read_only_functions?(address)
    end

    test "returns false when there is no read only functions" do
      smart_contract =
        insert(
          :smart_contract,
          abi: [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            }
          ]
        )

      address = insert(:address, smart_contract: smart_contract)

      refute AddressView.smart_contract_with_read_only_functions?(address)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      refute AddressView.smart_contract_with_read_only_functions?(address)
    end
  end
end
