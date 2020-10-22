defmodule BlockScoutWeb.Tokens.OverviewViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.OverviewView

  describe "decimals?/1" do
    test "returns true when Token has decimals" do
      token = insert(:token, decimals: 18)

      assert OverviewView.decimals?(token) == true
    end

    test "returns false when Token hasn't decimals" do
      token = insert(:token, decimals: nil)

      assert OverviewView.decimals?(token) == false
    end
  end

  describe "token_name?/1" do
    test "returns true when Token has a name" do
      token = insert(:token, name: "Some Token")

      assert OverviewView.token_name?(token) == true
    end

    test "returns false when Token hasn't a name" do
      token = insert(:token, name: nil)

      assert OverviewView.token_name?(token) == false
    end
  end

  describe "total_supply?/1" do
    test "returns true when Token has total_supply" do
      token = insert(:token, total_supply: 1_000)

      assert OverviewView.total_supply?(token) == true
    end

    test "returns false when Token hasn't total_supply" do
      token = insert(:token, total_supply: nil)

      assert OverviewView.total_supply?(token) == false
    end
  end

  describe "current_tab_name/1" do
    test "returns the correctly text for the token_transfers tab" do
      token_transfers_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"

      assert OverviewView.current_tab_name(token_transfers_path) == "Token Transfers"
    end

    test "returns the correctly text for the token_holders tab" do
      token_holders_path = "/page/0xSom3tH1ng/token-holders/?additional_params=blah"

      assert OverviewView.current_tab_name(token_holders_path) == "Token Holders"
    end

    test "returns the correctly text for the read_contract tab" do
      read_contract_path = "/page/0xSom3tH1ng/read-contract/?additional_params=blah"

      assert OverviewView.current_tab_name(read_contract_path) == "Read Contract"
    end
  end

  describe "display_inventory?/1" do
    test "returns true when token is unique" do
      token = insert(:token, type: "ERC-721")

      assert OverviewView.display_inventory?(token) == true
    end

    test "returns false when token is not unique" do
      token = insert(:token, type: "ERC-20")

      assert OverviewView.display_inventory?(token) == false
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

      token = insert(:token, contract_address: address)

      assert OverviewView.smart_contract_with_read_only_functions?(token)
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

      token = insert(:token, contract_address: address)

      refute OverviewView.smart_contract_with_read_only_functions?(token)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      token = insert(:token, contract_address: address)

      refute OverviewView.smart_contract_with_read_only_functions?(token)
    end
  end

  describe "total_supply_usd/1" do
    test "returns the correct total supply value" do
      token =
        :token
        |> build(decimals: Decimal.new(0), total_supply: Decimal.new(20))
        |> Map.put(:usd_value, Decimal.new(10))

      result = OverviewView.total_supply_usd(token)

      assert Decimal.cmp(result, Decimal.new(200)) == :eq
    end

    test "takes decimals into account" do
      token =
        :token
        |> build(decimals: Decimal.new(1), total_supply: Decimal.new(20))
        |> Map.put(:usd_value, Decimal.new(10))

      result = OverviewView.total_supply_usd(token)

      assert Decimal.cmp(result, Decimal.new(20)) == :eq
    end
  end
end
