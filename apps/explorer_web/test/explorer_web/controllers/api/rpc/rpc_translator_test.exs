defmodule ExplorerWeb.API.RPC.RPCTranslatorTest do
  use ExplorerWeb.ConnCase

  alias ExplorerWeb.API.RPC.RPCTranslator
  alias Plug.Conn

  defmodule TestController do
    use ExplorerWeb, :controller

    def test_action(conn, _) do
      json(conn, %{})
    end
  end

  setup %{conn: conn} do
    conn = Phoenix.Controller.accepts(conn, ["json"])
    {:ok, conn: conn}
  end

  test "init/1" do
    assert RPCTranslator.init([]) == []
  end

  describe "call" do
    test "with a bad module", %{conn: conn} do
      conn = %Conn{conn | params: %{"module" => "test", "action" => "test"}}

      result = RPCTranslator.call(conn, %{})
      assert result.halted
      assert response = json_response(result, 400)
      assert response["message"] =~ "Unknown action"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a bad action atom", %{conn: conn} do
      conn = %Conn{conn | params: %{"module" => "test", "action" => "some_atom_that_should_not_exist"}}

      result = RPCTranslator.call(conn, %{"test" => TestController})
      assert result.halted
      assert response = json_response(result, 400)
      assert response["message"] =~ "Unknown action"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid controller action", %{conn: conn} do
      conn = %Conn{conn | params: %{"module" => "test", "action" => "index"}}

      result = RPCTranslator.call(conn, %{"test" => TestController})
      assert result.halted
      assert response = json_response(result, 400)
      assert response["message"] =~ "Unknown action"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with missing params", %{conn: conn} do
      result = RPCTranslator.call(conn, %{"test" => TestController})
      assert result.halted
      assert response = json_response(result, 400)
      assert response["message"] =~ "'module' and 'action' are required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a valid request", %{conn: conn} do
      conn = %Conn{conn | params: %{"module" => "test", "action" => "test_action"}}

      result = RPCTranslator.call(conn, %{"test" => TestController})
      assert json_response(result, 200) == %{}
    end
  end

  test "translate_module/2" do
    assert RPCTranslator.translate_module(%{"test" => __MODULE__}, "tesT") == {:ok, __MODULE__}
    assert RPCTranslator.translate_module(%{}, "test") == :error
  end

  test "translate_action/1" do
    expected = :test_atom
    assert RPCTranslator.translate_action("test_atoM") == {:ok, expected}
    assert RPCTranslator.translate_action("some_atom_that_should_not_exist") == :error
  end

  test "call_controller/3", %{conn: conn} do
    assert RPCTranslator.call_controller(conn, TestController, :bad_action) == :error
    assert {:ok, %Plug.Conn{}} = RPCTranslator.call_controller(conn, TestController, :test_action)
  end
end
