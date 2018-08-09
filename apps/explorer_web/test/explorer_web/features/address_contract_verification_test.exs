defmodule ExplorerWeb.AddressContractVerificationTest do
  use ExplorerWeb.FeatureCase, async: true

  import Wallaby.Query

  alias Plug.Conn
  alias Explorer.Chain.Address
  alias Explorer.Factory

  setup do
    bypass = Bypass.open()

    Application.put_env(:explorer, :solc_bin_api_url, "http://localhost:#{bypass.port}")

    {:ok, bypass: bypass}
  end

  test "users validates smart contract", %{session: session, bypass: bypass} do
    Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, solc_bin_versions()) end)

    %{name: name, source_code: source_code, bytecode: bytecode, version: version} = Factory.contract_code_info()

    transaction = :transaction |> insert() |> with_block()
    address = %Address{hash: address_hash} = insert(:address, contract_code: bytecode)

    insert(
      :internal_transaction_create,
      created_contract_address: address,
      created_contract_code: bytecode,
      index: 0,
      transaction: transaction
    )

    session
    |> visit("/en/addresses/#{address_hash}/contract_verifications/new")
    |> fill_in(text_field("Contract Name"), with: name)
    |> click(option(version))
    |> click(radio_button("No"))
    |> fill_in(text_field("Enter the Solidity Contract Code below"), with: source_code)
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
    |> assert_has(css("[data-test='contract-source-code-error']", text: "there was an error validating your contract, please try again."))
  end

  def solc_bin_versions() do
    File.read!("./test/support/fixture/smart_contract/solc_bin.json")
  end
end
