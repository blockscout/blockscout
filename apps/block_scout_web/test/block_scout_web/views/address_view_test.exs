defmodule BlockScoutWeb.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.{Address, Data, Transaction}
  alias BlockScoutWeb.AddressView

  describe "address_partial_selector/4" do
    test "for a pending contract creation to address" do
      transaction = insert(:transaction, to_address: nil, created_contract_address_hash: nil)
      assert AddressView.address_partial_selector(transaction, :to, nil) == "Contract Address Pending"
    end

    test "will truncate address" do
      transaction = %Transaction{to_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_link.html",
               address_hash: ^hash,
               contract: false,
               truncate: true
             } = AddressView.address_partial_selector(transaction, :to, nil, true)
    end

    test "for a non-contract to address not on address page" do
      transaction = %Transaction{to_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_link.html",
               address_hash: ^hash,
               contract: false,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract to address non matching address page" do
      transaction = %Transaction{to_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_link.html",
               address_hash: ^hash,
               contract: false,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract to address matching address page" do
      transaction = %Transaction{to_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_responsive_hash.html",
               address_hash: ^hash,
               contract: false,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, transaction.to_address)
    end

    test "for a contract to address non matching address page" do
      contract = %Address{hash: hash} = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract)

      assert %{
               partial: "_link.html",
               address_hash: ^hash,
               contract: true,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, transaction.to_address)
    end

    test "for a contract to address matching address page" do
      contract = %Address{hash: hash} = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract)

      assert %{
               partial: "_responsive_hash.html",
               address_hash: ^hash,
               contract: true,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, contract)
    end

    test "for a non-contract from address not on address page" do
      transaction = %Transaction{to_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_link.html",
               address_hash: ^hash,
               contract: false,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract from address matching address page" do
      transaction = %Transaction{from_address_hash: hash} = insert(:transaction)

      assert %{
               partial: "_responsive_hash.html",
               address_hash: ^hash,
               contract: false,
               truncate: false
             } = AddressView.address_partial_selector(transaction, :from, transaction.from_address)
    end
  end

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

  describe "qr_code/1" do
    test "it returns an encoded value" do
      address = build(:address)
      assert {:ok, _} = Base.decode64(AddressView.qr_code(address))
    end
  end

  describe "render_partial/1" do
    test "renders _link partial" do
      %Address{hash: hash} = build(:address)

      assert {:safe, _} =
               AddressView.render_partial(%{partial: "_link.html", address_hash: hash, contract: false, truncate: false})
    end

    test "renders _responsive_hash partial" do
      %Address{hash: hash} = build(:address)

      assert {:safe, _} =
               AddressView.render_partial(%{
                 partial: "_responsive_hash.html",
                 address_hash: hash,
                 contract: false,
                 truncate: false
               })
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

  describe "token_title/1" do
    test "returns the 6 first chars of address hash when token has no name" do
      token = insert(:token, name: nil)

      expected_hash = to_string(token.contract_address_hash)
      assert String.starts_with?(expected_hash, AddressView.token_title(token))
    end

    test "returns name(symbol) when token has name" do
      token = insert(:token, name: "super token money", symbol: "ST$")

      assert AddressView.token_title(token) == "super token money (ST$)"
    end
  end
end
