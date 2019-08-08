defmodule BlockScoutWeb.API.V1.DecompiledControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Repo
  alias Explorer.Chain.{Address, DecompiledSmartContract}

  import Ecto.Query,
    only: [from: 2]

  @secret "secret"

  describe "when used authorized" do
    setup %{conn: conn} = context do
      Application.put_env(:block_scout_web, :decompiled_smart_contract_token, @secret)

      auth_conn = conn |> put_req_header("auth_token", @secret)

      {:ok, Map.put(context, :conn, auth_conn)}
    end

    test "returns unprocessable_entity status when params are invalid", %{conn: conn} do
      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create))

      assert request.status == 422
      assert request.resp_body == "{\"error\":\"address_hash is invalid\"}"
    end

    test "returns unprocessable_entity when code is empty", %{conn: conn} do
      decompiler_version = "test_decompiler"
      address = insert(:address)

      params = %{
        "address_hash" => to_string(address.hash),
        "decompiler_version" => decompiler_version
      }

      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create), params)

      assert request.status == 422
      assert request.resp_body == "{\"decompiled_source_code\":\"can't be blank\"}"
    end

    test "can not update code for the same decompiler version", %{conn: conn} do
      address_hash = to_string(insert(:address, hash: "0x0000000000000000000000000000000000000001").hash)
      decompiler_version = "test_decompiler"
      decompiled_source_code = "hello world"

      insert(:decompiled_smart_contract,
        address_hash: address_hash,
        decompiler_version: decompiler_version,
        decompiled_source_code: decompiled_source_code
      )

      params = %{
        "address_hash" => address_hash,
        "decompiler_version" => decompiler_version,
        "decompiled_source_code" => decompiled_source_code
      }

      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create), params)

      assert request.status == 422

      assert request.resp_body == "{\"error\":\"decompiled code already exists for the decompiler version\"}"
    end

    test "creates decompiled smart contract", %{conn: conn} do
      address_hash = to_string(insert(:address, hash: "0x0000000000000000000000000000000000000001").hash)
      decompiler_version = "test_decompiler"
      decompiled_source_code = "hello world"

      params = %{
        "address_hash" => address_hash,
        "decompiler_version" => decompiler_version,
        "decompiled_source_code" => decompiled_source_code
      }

      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create), params)

      assert request.status == 201

      assert request.resp_body ==
               "{\"address_hash\":\"0x0000000000000000000000000000000000000001\",\"decompiler_version\":\"test_decompiler\",\"decompiled_source_code\":\"hello world\"}"

      decompiled_smart_contract = Repo.one!(from(d in DecompiledSmartContract, where: d.address_hash == ^address_hash))
      assert to_string(decompiled_smart_contract.address_hash) == address_hash
      assert decompiled_smart_contract.decompiler_version == decompiler_version
      assert decompiled_smart_contract.decompiled_source_code == decompiled_source_code
    end

    test "updates the address to be decompiled", %{conn: conn} do
      address_hash = to_string(insert(:address, hash: "0x0000000000000000000000000000000000000001").hash)
      decompiler_version = "test_decompiler"
      decompiled_source_code = "hello world"

      params = %{
        "address_hash" => address_hash,
        "decompiler_version" => decompiler_version,
        "decompiled_source_code" => decompiled_source_code
      }

      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create), params)

      assert request.status == 201

      assert Repo.get!(Address, address_hash).decompiled
    end
  end

  describe "when user is not authorized" do
    test "returns forbedden", %{conn: conn} do
      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create))

      assert request.status == 403
    end
  end

  defp api_v1_decompiled_smart_contract_path(conn, action) do
    "/api" <> ApiRoutes.api_v1_decompiled_smart_contract_path(conn, action)
  end
end
