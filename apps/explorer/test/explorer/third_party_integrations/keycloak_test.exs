defmodule Explorer.ThirdPartyIntegrations.KeycloakTest do
  use ExUnit.Case, async: false

  alias Explorer.ThirdPartyIntegrations.Keycloak

  @user_id "0c1f5c1e-6f2a-4d3b-9b8e-2a7d5f4e3c21"
  @users_path "/admin/realms/test/users"
  @user_path "/admin/realms/test/users/#{@user_id}"
  @address_path "/realms/test/blockscout/users/#{@user_id}/address"
  @address "0x52908400098527886E0F7030069857D2E4169EE7"
  @stored_address "0x52908400098527886e0f7030069857d2e4169ee7"

  setup do
    bypass = Bypass.open()
    keycloak_env = Application.get_env(:explorer, Keycloak)
    tesla_adapter = Application.get_env(:tesla, :adapter)

    Application.put_env(
      :explorer,
      Keycloak,
      Keyword.merge(keycloak_env || [],
        domain: "http://localhost:#{bypass.port}",
        realm: "test",
        # unique client_id prevents reuse of an admin token cached in Redis by another test run
        client_id: "client_#{System.unique_integer([:positive])}",
        client_secret: "secret"
      )
    )

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, Keycloak, keycloak_env)
      Application.put_env(:tesla, :adapter, tesla_adapter)
    end)

    Bypass.stub(bypass, "POST", "/realms/test/protocol/openid-connect/token", fn conn ->
      Plug.Conn.resp(conn, 200, Utils.JSON.encode!(%{"access_token" => "token", "expires_in" => 300}))
    end)

    {:ok, bypass: bypass}
  end

  describe "link_address/2" do
    test "sets the address attribute", %{bypass: bypass} do
      test_pid = self()
      expect_users_with_address(bypass, [])

      Bypass.expect_once(bypass, "PUT", @address_path, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:address_put, Utils.JSON.decode!(body)})
        Plug.Conn.resp(conn, 204, "")
      end)

      Bypass.expect_once(bypass, "GET", @user_path, fn conn ->
        Plug.Conn.resp(conn, 200, Utils.JSON.encode!(user(%{"address" => [@stored_address]})))
      end)

      assert {:ok, %Ueberauth.Auth{uid: @user_id, extra: %{raw_info: %{address_hash: @address}}}} =
               Keycloak.link_address(@user_id, @address)

      # only the address is sent, the extension leaves other attributes as they are
      assert_receive {:address_put, body}
      assert body == %{"address" => @stored_address}
    end

    test "rejects address linked to another user", %{bypass: bypass} do
      expect_users_with_address(bypass, [user(%{"address" => [@stored_address]}, "another-user")])

      assert {:error, "Account with this address already exists"} = Keycloak.link_address(@user_id, @address)
    end

    # Several Blockscout instances share a realm, so a setting can be written while the address is being linked.
    # A read-modify-write of the whole user via the admin API drops the setting when the user was read before the
    # setting was written. The fake Keycloak always returns such a stale user on read.
    test "keeps attributes written concurrently", %{bypass: bypass} do
      attributes = start_supervised!({Agent, fn -> %{"settings.theme" => ["dark"]} end})
      stale_user = user(%{})
      expect_users_with_address(bypass, [])

      # admin API: reads return the stale user, writes replace all attributes
      Bypass.stub(bypass, "GET", @user_path, fn conn ->
        Plug.Conn.resp(conn, 200, Utils.JSON.encode!(stale_user))
      end)

      Bypass.stub(bypass, "PUT", @user_path, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Agent.update(attributes, fn _ -> Utils.JSON.decode!(body)["attributes"] end)
        Plug.Conn.resp(conn, 204, "")
      end)

      # extension: sets the address attribute only
      Bypass.stub(bypass, "PUT", @address_path, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        address = Utils.JSON.decode!(body)["address"]
        Agent.update(attributes, &Map.put(&1, "address", [address]))
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, _auth} = Keycloak.link_address(@user_id, @address)

      assert Agent.get(attributes, & &1) == %{"settings.theme" => ["dark"], "address" => [@stored_address]}
    end
  end

  defp expect_users_with_address(bypass, users) do
    Bypass.expect_once(bypass, "GET", @users_path, fn conn ->
      assert conn.query_string == URI.encode_query(%{q: "address:#{@stored_address}"})
      Plug.Conn.resp(conn, 200, Utils.JSON.encode!(users))
    end)
  end

  defp user(attributes, id \\ @user_id) do
    %{"id" => id, "username" => "user", "email" => "user@example.com", "enabled" => true, "attributes" => attributes}
  end
end
