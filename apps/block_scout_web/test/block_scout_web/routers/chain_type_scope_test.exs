defmodule BlockScoutWeb.Routers.ChainTypeScopeTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :default do
    describe "stability validators routes with chain_scope" do
      setup do
        original_chain_type = Application.get_env(:explorer, :chain_type)

        on_exit(fn ->
          Application.put_env(:explorer, :chain_type, original_chain_type)
        end)

        :ok
      end

      test "stability validators counters are accessible when chain type is stability", %{conn: conn} do
        Application.put_env(:explorer, :chain_type, :stability)

        assert _response =
                 conn
                 |> get("/api/v2/validators/stability/counters")
                 |> json_response(200)
      end

      test "stability validators list are not accessible with different chain type", %{conn: conn} do
        Application.put_env(:explorer, :chain_type, :default)

        conn = get(conn, "/api/v2/validators/stability/counters")
        response = json_response(conn, 404)
        assert response["message"] == "Endpoint not available for current chain type"
      end
    end

    test "blackfort validators counters are accessible when chain type is blackfort and stability is not",
         %{conn: conn} do
      chain_type = Application.get_env(:explorer, :chain_type)
      Application.put_env(:explorer, :chain_type, :blackfort)

      on_exit(fn ->
        Application.put_env(:explorer, :chain_type, chain_type)
      end)

      assert conn
             |> get("/api/v2/validators/blackfort/counters")
             |> json_response(200)

      assert conn
             |> get("/api/v2/validators/stability/counters")
             |> json_response(404)
    end
  end
end
