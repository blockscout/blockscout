defmodule ExplorerWeb.AddressContractVerificationTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query

  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    Application.put_env(:explorer, :solc_bin_api_url, "http://localhost:#{bypass.port}")

    {:ok, bypass: bypass}
  end

  test "users validates smart contract", %{session: session, bypass: bypass} do
    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, solc_bin_versions()) end)

    address_hash = "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"

    smart_contract_bytecode =
      "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

    created_contract_address = insert(:address, hash: address_hash, contract_code: smart_contract_bytecode)

    insert(
      :internal_transaction,
      index: 0,
      created_contract_address_hash: created_contract_address.hash,
      created_contract_code: smart_contract_bytecode
    )

    code = """
    pragma solidity ^0.4.24;

    contract SimpleStorage {
        uint storedData;

        function set(uint x) public {
            storedData = x;
        }

        function get() public constant returns (uint) {
            return storedData;
        }
    }
    """

    session
    |> visit("/en/addresses/#{address_hash}/contract_verifications/new")
    |> fill_in(text_field("Contract Name"), with: "SimpleStorage")
    |> click(option("0.4.24"))
    |> click(radio_button("No"))
    |> fill_in(text_field("Enter the Solidity Contract Code below"), with: code)
    |> click(button("Verify and publish"))

    assert current_path(session) =~ ~r/\/en\/addresses\/#{address_hash}\/contracts/
  end

  test "with invalid data shows error messages", %{session: session, bypass: bypass} do
    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, solc_bin_versions()) end)

    session
    |> visit("/en/addresses/0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461/contract_verifications/new")
    |> fill_in(text_field("Contract Name"), with: "")
    |> fill_in(text_field("Enter the Solidity Contract Code below"), with: "")
    |> click(button("Verify and publish"))
    |> assert_has(css(".has-error", text: "there was an error validating your contract, please try again."))
  end

  def solc_bin_versions() do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
