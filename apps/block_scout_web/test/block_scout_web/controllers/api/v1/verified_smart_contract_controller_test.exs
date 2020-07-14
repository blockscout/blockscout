defmodule BlockScoutWeb.API.V1.VerifiedControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Factory

  # alias Explorer.Chain.DecompiledSmartContract

  # import Ecto.Query,
  #   only: [from: 2]

  test "verifying a standard smart contract", %{conn: conn} do
    contract_code_info = Factory.contract_code_info()

    contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)
    insert(:transaction, created_contract_address_hash: contract_address.hash, input: contract_code_info.tx_input)

    params = %{
      "address_hash" => to_string(contract_address.hash),
      "name" => contract_code_info.name,
      "compiler_version" => contract_code_info.version,
      "optimization" => contract_code_info.optimized,
      "contract_source_code" => contract_code_info.source_code
    }

    response = post(conn, api_v1_verified_smart_contract_path(conn, :create), params)

    assert response.status == 201
    assert Jason.decode!(response.resp_body) == %{"status" => "success"}
  end

  test "verifying a smart contract with external libraries", %{conn: conn} do
    contract_data =
      "#{File.cwd!()}/test/support/fixture/smart_contract/contract_with_lib.json"
      |> File.read!()
      |> Jason.decode!()
      |> List.first()

    %{
      "compiler_version" => compiler_version,
      "external_libraries" => external_libraries,
      "name" => name,
      "optimize" => optimize,
      "contract" => contract_source_code,
      "tx_input" => tx_input,
      "expected_bytecode" => expected_bytecode
    } = contract_data

    contract_address = insert(:contract_address, contract_code: "0x" <> expected_bytecode)
    insert(:transaction, created_contract_address_hash: contract_address.hash, input: "0x" <> tx_input)

    params = %{
      "address_hash" => to_string(contract_address.hash),
      "name" => name,
      "compiler_version" => compiler_version,
      "optimization" => optimize,
      "contract_source_code" => contract_source_code
    }

    params_with_external_libraries =
      external_libraries
      |> Enum.with_index()
      |> Enum.reduce(params, fn {{name, address}, index}, acc ->
        name_key = "library#{index + 1}_name"
        address_key = "library#{index + 1}_address"

        acc
        |> Map.put(name_key, name)
        |> Map.put(address_key, address)
      end)

    response = post(conn, api_v1_verified_smart_contract_path(conn, :create), params_with_external_libraries)

    assert response.status == 201
    assert Jason.decode!(response.resp_body) == %{"status" => "success"}
  end

  defp api_v1_verified_smart_contract_path(conn, action) do
    "/api" <> ApiRoutes.api_v1_verified_smart_contract_path(conn, action)
  end
end
