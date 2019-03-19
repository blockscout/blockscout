defmodule BlockScoutWeb.API.V1.DecompiledControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Repo
  alias Explorer.Chain.DecompiledSmartContract

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
    end

    test "creates decompiled smart contract", %{conn: conn} do
      address_hash = to_string(insert(:address).hash)
      decompiler_version = "test_decompiler"
      decompiled_source_code = "hello world"

      params = %{
        "address_hash" => address_hash,
        "decompiler_version" => decompiler_version,
        "decompiled_source_code" => decompiled_source_code
      }

      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create), params)

      assert request.status == 201

      decompiled_smart_contract = Repo.one!(from(d in DecompiledSmartContract, where: d.address_hash == ^address_hash))
      assert to_string(decompiled_smart_contract.address_hash) == address_hash
      assert decompiled_smart_contract.decompiler_version == decompiler_version
      assert decompiled_smart_contract.decompiled_source_code == decompiled_source_code
    end
  end

  describe "when user is not authorized" do
    test "returns forbedden", %{conn: conn} do
      request = post(conn, api_v1_decompiled_smart_contract_path(conn, :create))

      assert request.status == 403
    end
  end
end
