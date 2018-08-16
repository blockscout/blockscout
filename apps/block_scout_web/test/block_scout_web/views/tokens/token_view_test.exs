defmodule BlockScoutWeb.Tokens.TokenViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.TokenView

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

      assert TokenView.smart_contract_with_read_only_functions?(token)
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

      refute TokenView.smart_contract_with_read_only_functions?(token)
    end

    test "returns false when smart contract is not verified" do
      address = insert(:address, smart_contract: nil)

      token = insert(:token, contract_address: address)

      refute TokenView.smart_contract_with_read_only_functions?(token)
    end
  end
end
