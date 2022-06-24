defmodule BlockScoutWeb.API.RPC.ENSControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  describe "ensaddress" do
    test "with missing name param", %{conn: conn} do
      params = %{
        "module" => "ens",
        "action" => "ensaddress"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Query parameter 'name' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(ensaddress_schema(), response)
    end
  end

  describe "ensname" do
    test "with missing address param", %{conn: conn} do
      params = %{
        "module" => "ens",
        "action" => "ensname"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Query parameter 'address' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(ensname_schema(), response)
    end

    test "with an invalid address", %{conn: conn} do
      params = %{
        "module" => "ens",
        "action" => "ensname",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(ensname_schema(), response)
    end
  end

  defp ensaddress_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp ensname_schema do
    resolve_schema(%{
      "type" => ["string", "null"]
    })
  end

  defp resolve_schema(result \\ %{}) do
    %{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"}
      }
    }
    |> put_in(["properties", "result"], result)
    |> ExJsonSchema.Schema.resolve()
  end
end
