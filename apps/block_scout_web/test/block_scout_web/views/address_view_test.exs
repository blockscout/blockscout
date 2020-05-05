defmodule BlockScoutWeb.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.Chain.{Address, Data, Hash, Transaction}
  alias BlockScoutWeb.{AddressView, Endpoint}

  describe "address_partial_selector/4" do
    test "for a pending transaction contract creation to address" do
      transaction = insert(:transaction, to_address: nil, created_contract_address_hash: nil)
      assert AddressView.address_partial_selector(transaction, :to, nil) == "Contract Address Pending"
    end

    test "for a pending internal transaction contract creation to address" do
      transaction = insert(:transaction, to_address: nil) |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          to_address: nil,
          created_contract_address_hash: nil,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      assert "Contract Address Pending" == AddressView.address_partial_selector(internal_transaction, :to, nil)
    end

    test "will truncate address" do
      transaction = %Transaction{to_address: to_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_link.html",
               address: ^to_address,
               contract: false,
               truncate: true,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, nil, true)
    end

    test "for a non-contract to address not on address page" do
      transaction = %Transaction{to_address: to_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_link.html",
               address: ^to_address,
               contract: false,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract to address non matching address page" do
      transaction = %Transaction{to_address: to_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_link.html",
               address: ^to_address,
               contract: false,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract to address matching address page" do
      transaction = %Transaction{to_address: to_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_responsive_hash.html",
               address: ^to_address,
               contract: false,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, transaction.to_address)
    end

    test "for a contract to address non matching address page" do
      contract_address = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract_address)

      assert [
               view_module: AddressView,
               partial: "_link.html",
               address: ^contract_address,
               contract: true,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, transaction.to_address)
    end

    test "for a contract to address matching address page" do
      contract_address = insert(:contract_address)
      transaction = insert(:transaction, to_address: nil, created_contract_address: contract_address)

      assert [
               view_module: AddressView,
               partial: "_responsive_hash.html",
               address: ^contract_address,
               contract: true,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, contract_address)
    end

    test "for a non-contract from address not on address page" do
      transaction = %Transaction{to_address: to_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_link.html",
               address: ^to_address,
               contract: false,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :to, nil)
    end

    test "for a non-contract from address matching address page" do
      transaction = %Transaction{from_address: from_address} = insert(:transaction)

      assert [
               view_module: AddressView,
               partial: "_responsive_hash.html",
               address: ^from_address,
               contract: false,
               truncate: false,
               use_custom_tooltip: false
             ] = AddressView.address_partial_selector(transaction, :from, transaction.from_address)
    end
  end

  describe "balance_block_number/1" do
    test "gives empty string with no fetched balance block number present" do
      assert AddressView.balance_block_number(%Address{}) == ""
    end

    test "gives block number when fetched balance block number is non-nil" do
      assert AddressView.balance_block_number(%Address{fetched_coin_balance_block_number: 1_000_000}) == "1000000"
    end
  end

  describe "balance_percentage_enabled/1" do
    test "with non_zero market cap" do
      Application.put_env(:block_scout_web, :show_percentage, true)

      assert AddressView.balance_percentage_enabled?(100_500) == true
    end

    test "with zero market cap" do
      Application.put_env(:block_scout_web, :show_percentage, true)

      assert AddressView.balance_percentage_enabled?(0) == false
    end

    test "with switched off show_percentage" do
      Application.put_env(:block_scout_web, :show_percentage, false)

      assert AddressView.balance_percentage_enabled?(100_501) == false
    end
  end

  test "balance_percentage/1" do
    Application.put_env(:explorer, :supply, Explorer.Chain.Supply.ProofOfAuthority)
    address = insert(:address, fetched_coin_balance: 2_524_608_000_000_000_000_000_000)

    assert "1.0000% Market Cap" = AddressView.balance_percentage(address)
  end

  test "balance_percentage with nil total_supply" do
    address = insert(:address, fetched_coin_balance: 2_524_608_000_000_000_000_000_000)

    assert "" = AddressView.balance_percentage(address, nil)
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

  describe "hash/1" do
    test "gives a string version of an address's hash" do
      address = %Address{
        hash: %Hash{
          byte_count: 20,
          bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
        }
      }

      assert AddressView.hash(address) == "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
    end
  end

  describe "primary_name/1" do
    test "gives an address's primary name when present" do
      address = insert(:address)

      address_name = insert(:address_name, address: address, primary: true, name: "POA Foundation Wallet")
      insert(:address_name, address: address, name: "POA Wallet")

      preloaded_address = Explorer.Repo.preload(address, :names)

      assert AddressView.primary_name(preloaded_address) == address_name.name
    end

    test "returns nil when no primary available" do
      address_name = insert(:address_name, name: "POA Wallet")
      preloaded_address = Explorer.Repo.preload(address_name.address, :names)

      refute AddressView.primary_name(preloaded_address)
    end
  end

  describe "qr_code/1" do
    test "it returns an encoded value" do
      address = build(:address)
      assert {:ok, _} = Base.decode64(AddressView.qr_code(address.hash))
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

  describe "current_tab_name/1" do
    test "generates the correct tab name for the token path" do
      path = address_token_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Tokens"
    end

    test "generates the correct tab name for the transactions path" do
      path = address_transaction_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Transactions"
    end

    test "generates the correct tab name for the internal transactions path" do
      path = address_internal_transaction_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Internal Transactions"
    end

    test "generates the correct tab name for the contracts path" do
      path = address_contract_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Code"
    end

    test "generates the correct tab name for the read_contract path" do
      path = address_read_contract_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Read Contract"
    end

    test "generates the correct tab name for the coin_balances path" do
      path = address_coin_balance_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Coin Balance History"
    end

    test "generates the correct tab name for the validations path" do
      path = address_validation_path(Endpoint, :index, "0x4ddr3s")

      assert AddressView.current_tab_name(path) == "Blocks Validated"
    end
  end

  describe "short_hash/1" do
    test "returns a shortened hash of 6 hex characters" do
      address = insert(:address)
      assert "0x" <> short_hash = AddressView.short_hash(address)
      assert String.length(short_hash) == 6
    end
  end

  describe "address_page_title/1" do
    test "uses the Smart Contract name when the contract is verified" do
      smart_contract = build(:smart_contract, name: "POA")
      address = build(:address, smart_contract: smart_contract)

      assert AddressView.address_page_title(address) == "POA (#{address})"
    end

    test "uses the string 'Contract' when it's a contract" do
      address = build(:contract_address, smart_contract: nil)

      assert AddressView.address_page_title(address) == "Contract #{address}"
    end

    test "uses the address hash when it is not a contract" do
      address = build(:address, smart_contract: nil)

      assert AddressView.address_page_title(address) == "#{address}"
    end
  end
end
