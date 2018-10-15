defmodule BlockScoutWeb.Plug.Admin.CheckOwnerRegisteredTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Plug.Admin.CheckOwnerRegistered
  alias Explorer.Admin

  test "init/1" do
    assert CheckOwnerRegistered.init([]) == []
  end

  describe "call/2" do
    test "redirects if owner user isn't configured", %{conn: conn} do
      assert {:error, _} = Admin.owner()
      result = CheckOwnerRegistered.call(conn, [])
      assert redirected_to(result) == AdminRoutes.setup_path(conn, :configure)
      assert result.halted
    end

    test "continues if owner user is configured", %{conn: conn} do
      insert(:administrator)
      assert {:ok, _} = Admin.owner()
      result = CheckOwnerRegistered.call(conn, [])
      assert result.state == :unset
      refute result.halted
    end
  end
end
