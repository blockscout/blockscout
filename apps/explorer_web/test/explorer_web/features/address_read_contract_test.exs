defmodule ExplorerWeb.AddressReadContractTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query

  alias Plug.Conn

  @ethereum_jsonrpc_original Application.get_env(:ethereum_jsonrpc, :url)

  setup do
    bypass = Bypass.open()

    Application.put_env(:ethereum_jsonrpc, :url, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.put_env(:ethereum_jsonrpc, :url, @ethereum_jsonrpc_original)
    end)

    {:ok, bypass: bypass}
  end

  test "user can query a function from the smart contract", %{session: session, bypass: bypass} do
    smart_contract_bytecode =
      "0x608060405260043610610057576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b11461005c5780636d4ce63c14610089578063acbe7b79146100b4575b600080fd5b34801561006857600080fd5b50610087600480360381019080803590602001909291905050506100f9565b005b34801561009557600080fd5b5061009e610103565b6040518082815260200191505060405180910390f35b3480156100c057600080fd5b506100df6004803603810190808035906020019092919050505061010c565b604051808215151515815260200191505060405180910390f35b8060008190555050565b60008054905090565b60008054821490509190505600a165627a7a723058201b7ca1dc6f88d76a0aa8279bc79a934469d7b90a4af3be3d2b7490f34db10fe10029"

    created_contract_address = insert(:address, contract_code: smart_contract_bytecode)

    smart_contract =
      insert(
        :smart_contract,
        address_hash: created_contract_address.hash,
        abi: [
          %{
            "constant" => true,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "with_arguments",
            "outputs" => [%{"name" => "", "type" => "bool"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ]
      )

    Bypass.expect(bypass, fn conn ->
      Conn.resp(
        conn,
        200,
        ~s[{"jsonrpc":"2.0","result":"0x0000000000000000000000000000000000000000000000000000000000000000","id":"with_arguments"}]
      )
    end)

    session
    |> visit("/en/addresses/#{smart_contract.address_hash}/read_contract")
    |> fill_in(text_field("function_input"), with: 0)
    |> click(button("Query"))
    |> assert_has(css("[data-function-response]", text: "[ with_arguments method Response ]"))
  end
end
