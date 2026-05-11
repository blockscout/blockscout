defmodule Explorer.Market.Fetcher.TokenListTest do
  use Explorer.DataCase

  alias Explorer.Chain.Token
  alias Explorer.Market.Fetcher.TokenList

  @moduletag :capture_log

  setup do
    bypass = Bypass.open()

    original_config = Application.get_env(:explorer, TokenList)
    original_chain_id = Application.get_env(:explorer, :chain_id)

    Application.put_env(
      :explorer,
      TokenList,
      Keyword.merge(original_config || [],
        enabled: true,
        token_list_url: "http://localhost:#{bypass.port}/tokens.json",
        refetch_interval: :timer.hours(24)
      )
    )

    Application.put_env(:explorer, :chain_id, "77")
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:explorer, TokenList, original_config)
      Application.put_env(:explorer, :chain_id, original_chain_id)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)

    {:ok, %{bypass: bypass}}
  end

  defp token_list_json(tokens) do
    Jason.encode!(%{
      "name" => "Test Token List",
      "tokens" => tokens
    })
  end

  defp token_entry(address, opts) do
    %{
      "address" => to_string(address),
      "chainId" => opts[:chain_id] || 77,
      "name" => opts[:name] || "Test Token",
      "symbol" => opts[:symbol] || "TST",
      "decimals" => opts[:decimals] || 18,
      "logoURI" => opts[:logo_uri] || "https://example.com/logo.png"
    }
  end

  describe "init/1" do
    test "returns :ignore when token_list_url is not set" do
      Application.put_env(:explorer, TokenList, enabled: true, token_list_url: nil)

      assert :ignore = TokenList.init(:ok)
    end

    test "starts when token_list_url is set" do
      assert {:ok, %TokenList{url: url}} = TokenList.init(:ok)
      assert url == Application.get_env(:explorer, TokenList)[:token_list_url]
    end
  end

  describe "fetch and import" do
    test "imports tokens matching chain_id", %{bypass: bypass} do
      token = insert(:token, icon_url: nil, name: nil, symbol: nil, decimals: nil)
      other_token = insert(:token, icon_url: nil)

      body =
        token_list_json([
          token_entry(token.contract_address_hash,
            name: "Listed Token",
            symbol: "LTK",
            decimals: 18,
            logo_uri: "https://example.com/listed.png"
          ),
          token_entry(other_token.contract_address_hash,
            chain_id: 999,
            name: "Other Chain Token",
            logo_uri: "https://example.com/other.png"
          )
        ])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)

      updated_token = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert updated_token.icon_url == "https://example.com/listed.png"
      assert updated_token.name == "Listed Token"
      assert updated_token.symbol == "LTK"

      # Token from chain_id 999 should NOT be updated
      other_updated = Repo.get_by(Token, contract_address_hash: other_token.contract_address_hash)
      assert is_nil(other_updated.icon_url)
    end

    test "does not overwrite existing name, symbol, decimals", %{bypass: bypass} do
      token = insert(:token, name: "Original Name", symbol: "OG", decimals: 8, icon_url: nil)

      body =
        token_list_json([
          token_entry(token.contract_address_hash,
            name: "New Name",
            symbol: "NEW",
            decimals: 18,
            logo_uri: "https://example.com/new.png"
          )
        ])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)

      updated_token = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert updated_token.name == "Original Name"
      assert updated_token.symbol == "OG"
      assert updated_token.decimals == Decimal.new(8)
      assert updated_token.icon_url == "https://example.com/new.png"
    end

    test "does not overwrite icon_url for admin-verified tokens", %{bypass: bypass} do
      token =
        insert(:token,
          icon_url: "https://admin.example.com/icon.png",
          is_verified_via_admin_panel: true
        )

      body =
        token_list_json([
          token_entry(token.contract_address_hash,
            logo_uri: "https://example.com/list-icon.png"
          )
        ])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)

      updated_token = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert updated_token.icon_url == "https://admin.example.com/icon.png"
    end

    test "overwrites icon_url for non-admin tokens", %{bypass: bypass} do
      token =
        insert(:token,
          icon_url: "https://old.example.com/icon.png",
          is_verified_via_admin_panel: false
        )

      body =
        token_list_json([
          token_entry(token.contract_address_hash,
            logo_uri: "https://example.com/new-icon.png"
          )
        ])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)

      updated_token = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert updated_token.icon_url == "https://example.com/new-icon.png"
    end

    test "handles HTTP error gracefully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)
    end

    test "handles invalid JSON gracefully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, "not json")
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)
    end

    test "handles empty token list", %{bypass: bypass} do
      body = token_list_json([])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)
    end

    test "skips tokens with missing address field", %{bypass: bypass} do
      body =
        Jason.encode!(%{
          "name" => "Test List",
          "tokens" => [
            %{"chainId" => 77, "name" => "No Address", "symbol" => "NA", "decimals" => 18}
          ]
        })

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)
    end

    test "imports all tokens when CHAIN_ID is not set", %{bypass: bypass} do
      Application.put_env(:explorer, :chain_id, nil)

      token = insert(:token, icon_url: nil)

      body =
        token_list_json([
          token_entry(token.contract_address_hash, chain_id: 999, logo_uri: "https://example.com/any.png")
        ])

      Bypass.expect_once(bypass, "GET", "/tokens.json", fn conn ->
        Plug.Conn.resp(conn, 200, body)
      end)

      {:ok, pid} = GenServer.start_link(TokenList, :ok)
      :timer.sleep(200)
      GenServer.stop(pid)

      updated_token = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert updated_token.icon_url == "https://example.com/any.png"
    end
  end
end
