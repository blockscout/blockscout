defmodule BlockScoutWeb.Plug.ValidateRouteParametersTest do
  use BlockScoutWeb.ConnCase

  import Plug.Conn
  alias BlockScoutWeb.Plug.ValidateRouteParameters
  alias BlockScoutWeb.Router

  describe "call/2" do
    setup %{conn: conn} do
      conn =
        conn
        |> bypass_through(Router, [:browser])
        |> get("/")

      {:ok, conn: conn}
    end

    test "doesn't invalidate base conn", %{conn: conn} do
      result = conn |> ValidateRouteParameters.call(nil)

      refute result.halted
    end

    test "doesn't invalidate when validation set but no matching params", %{conn: conn} do
      result =
        conn
        |> put_private(:validate, %{"test_key" => :validation_func})
        |> ValidateRouteParameters.call(nil)

      refute result.halted
    end

    test "invalidates against function", %{conn: conn} do
      conn_with_validation =
        conn
        |> put_private(:validate, %{"test_key" => &(&1 == "expected_value")})

      failed_conn =
        %{conn_with_validation | params: Map.merge(conn_with_validation.params, %{"test_key" => "bad_value"})}
        |> ValidateRouteParameters.call(nil)

      assert failed_conn.halted

      valid_conn =
        %{conn_with_validation | params: Map.merge(conn_with_validation.params, %{"test_key" => "expected_value"})}
        |> ValidateRouteParameters.call(nil)

      refute valid_conn.halted
    end

    test "handles valid address", %{conn: conn} do
      valid_address = "0x57AbAE14E7F223aB8C4D2C9bDe135b8Ff6b884ec"

      test_conn =
        %{conn | params: Map.merge(conn.params, %{"address_id" => valid_address})}
        |> put_private(:validate, %{"address_id" => :is_address})

      result = test_conn |> ValidateRouteParameters.call(nil)

      refute test_conn.halted
    end

    test "handles invalid address", %{conn: conn} do
      invalid_address = "0x5asdflkj;jl;k(*&"

      test_conn =
        %{conn | params: Map.merge(conn.params, %{"address_id" => invalid_address})}
        |> put_private(:validate, %{"address_id" => :is_address})
        |> ValidateRouteParameters.call(nil)

      assert test_conn.halted
    end

    test "handles xss attempt", %{conn: conn} do
      xss_address = "0x57AbAE14E7F223aB8C4D2C9bDe135b8Ff6b884ecp4fg%20onfocus%3dalert(origin)%20autofocus"

      test_conn =
        %{conn | params: Map.merge(conn.params, %{"address_id" => xss_address})}
        |> put_private(:validate, %{"address_id" => :is_address})
        |> ValidateRouteParameters.call(nil)

      assert test_conn.halted
    end

    test "handles non hex input", %{conn: conn} do
      non_hex_input = "invalid_address"

      test_conn =
        %{conn | params: Map.merge(conn.params, %{"address_id" => non_hex_input})}
        |> put_private(:validate, %{"address_id" => :is_address})
        |> ValidateRouteParameters.call(nil)

      assert test_conn.halted
    end
  end
end
