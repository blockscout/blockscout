defmodule BlockScoutWeb.Account.Api.V1.UserControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Guardian
  alias BlockScoutWeb.Models.UserFromAuth

  setup %{conn: conn} do
    auth = build(:auth)

    {:ok, user} = UserFromAuth.find_or_create(auth)

    {:ok, token, _} = Guardian.encode_and_sign(user)

    {:ok, user: user, conn: Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)}
  end

  describe "Test account/api/v1/user" do
    test "get user info", %{conn: conn, user: user} do
      result_conn =
        conn
        |> get("/api/account/v1/user/info")
        |> doc(description: "Get info about user")

      assert json_response(result_conn, 200) == %{
               "nickname" => user.nickname,
               "name" => user.name,
               "email" => user.email,
               "avatar" => user.avatar
             }
    end

    test "post private address tag", %{conn: conn} do
      tag_address_response =
        conn
        |> post("/api/account/v1/user/tags/address", %{
          "address_hash" => "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b",
          "name" => "MyName"
        })
        |> doc(description: "Add private address tag")
        |> json_response(200)

      conn
      |> get("/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b")
      |> doc(description: "Get tags for address")
      |> json_response(200)

      assert tag_address_response["address_hash"] == "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
      assert tag_address_response["name"] == "MyName"
      assert tag_address_response["id"]
    end

    test "get address tags after inserting one private tags", %{conn: conn} do
      addresses = Enum.map(0..2, fn _x -> to_string(build(:address).hash) end)
      names = Enum.map(0..2, fn x -> "name#{x}" end)
      zipped = Enum.zip(addresses, names)

      created =
        Enum.map(zipped, fn {addr, name} ->
          id =
            (conn
             |> post("/api/account/v1/user/tags/address", %{
               "address_hash" => addr,
               "name" => name
             })
             |> json_response(200))["id"]

          {addr, %{"display_name" => name, "label" => name}, %{"address_hash" => addr, "id" => id, "name" => name}}
        end)

      assert Enum.all?(created, fn {addr, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/address/#{addr}")
                 |> json_response(200)

               response["personal_tags"] == [map_tag]
             end)

      response =
        conn
        |> get("/api/account/v1/user/tags/address")
        |> doc(description: "Get private addresses tags")
        |> json_response(200)

      assert Enum.all?(created, fn {_, _, map} -> map in response end)
    end

    test "delete address tag", %{conn: conn} do
      addresses = Enum.map(0..2, fn _x -> to_string(build(:address).hash) end)
      names = Enum.map(0..2, fn x -> "name#{x}" end)
      zipped = Enum.zip(addresses, names)

      created =
        Enum.map(zipped, fn {addr, name} ->
          id =
            (conn
             |> post("/api/account/v1/user/tags/address", %{
               "address_hash" => addr,
               "name" => name
             })
             |> json_response(200))["id"]

          {addr, %{"display_name" => name, "label" => name}, %{"address_hash" => addr, "id" => id, "name" => name}}
        end)

      assert Enum.all?(created, fn {addr, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/address/#{addr}")
                 |> json_response(200)

               response["personal_tags"] == [map_tag]
             end)

      response =
        conn
        |> get("/api/account/v1/user/tags/address")
        |> json_response(200)

      assert Enum.all?(created, fn {_, _, map} -> map in response end)

      {_, _, %{"id" => id}} = Enum.at(created, 0)

      assert conn
             |> delete("/api/account/v1/user/tags/address/#{id}")
             |> doc("Delete private address tag")
             |> response(200) == ""

      assert Enum.all?(Enum.drop(created, 1), fn {_, _, %{"id" => id}} ->
               conn
               |> delete("/api/account/v1/user/tags/address/#{id}")
               |> response(200) == ""
             end)

      assert conn
             |> get("/api/account/v1/user/tags/address")
             |> json_response(200) == []

      assert Enum.all?(created, fn {addr, _, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/address/#{addr}")
                 |> json_response(200)

               response["personal_tags"] == []
             end)
    end

    test "post private transaction tag", %{conn: conn} do
      tx_hash_non_existing = to_string(build(:transaction).hash)
      tx_hash = to_string(insert(:transaction).hash)

      assert conn
             |> post("/api/account/v1/user/tags/transaction", %{
               "transaction_hash" => tx_hash_non_existing,
               "name" => "MyName"
             })
             |> doc(description: "Error on try to create private transaction tag for tx does not exist")
             |> json_response(422) == %{"errors" => %{"tx_hash" => ["Transaction does not exist"]}}

      tag_transaction_response =
        conn
        |> post("/api/account/v1/user/tags/transaction", %{
          "transaction_hash" => tx_hash,
          "name" => "MyName"
        })
        |> doc(description: "Create private transaction tag")
        |> json_response(200)

      conn
      |> get("/api/account/v1/tags/transaction/#{tx_hash}")
      |> doc(description: "Get tags for transaction")
      |> json_response(200)

      assert tag_transaction_response["transaction_hash"] == tx_hash
      assert tag_transaction_response["name"] == "MyName"
      assert tag_transaction_response["id"]
    end

    test "get transaction tags after inserting one private tags", %{conn: conn} do
      transactions = Enum.map(0..2, fn _x -> to_string(insert(:transaction).hash) end)
      names = Enum.map(0..2, fn x -> "name#{x}" end)
      zipped = Enum.zip(transactions, names)

      created =
        Enum.map(zipped, fn {tx_hash, name} ->
          id =
            (conn
             |> post("/api/account/v1/user/tags/transaction", %{
               "transaction_hash" => tx_hash,
               "name" => name
             })
             |> json_response(200))["id"]

          {tx_hash, %{"label" => name}, %{"transaction_hash" => tx_hash, "id" => id, "name" => name}}
        end)

      assert Enum.all?(created, fn {tx_hash, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/transaction/#{tx_hash}")
                 |> json_response(200)

               response["personal_tx_tag"] == map_tag
             end)

      response =
        conn
        |> get("/api/account/v1/user/tags/transaction")
        |> doc(description: "Get private transactions tags")
        |> json_response(200)

      assert Enum.all?(created, fn {_, _, map} -> map in response end)
    end

    test "delete transaction tag", %{conn: conn} do
      transactions = Enum.map(0..2, fn _x -> to_string(insert(:transaction).hash) end)
      names = Enum.map(0..2, fn x -> "name#{x}" end)
      zipped = Enum.zip(transactions, names)

      created =
        Enum.map(zipped, fn {tx_hash, name} ->
          id =
            (conn
             |> post("/api/account/v1/user/tags/transaction", %{
               "transaction_hash" => tx_hash,
               "name" => name
             })
             |> json_response(200))["id"]

          {tx_hash, %{"label" => name}, %{"transaction_hash" => tx_hash, "id" => id, "name" => name}}
        end)

      assert Enum.all?(created, fn {tx_hash, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/transaction/#{tx_hash}")
                 |> json_response(200)

               response["personal_tx_tag"] == map_tag
             end)

      response =
        conn
        |> get("/api/account/v1/user/tags/transaction")
        |> json_response(200)

      assert Enum.all?(created, fn {_, _, map} -> map in response end)

      {_, _, %{"id" => id}} = Enum.at(created, 0)

      assert conn
             |> delete("/api/account/v1/user/tags/transaction/#{id}")
             |> doc("Delete private transaction tag")
             |> response(200) == ""

      assert Enum.all?(Enum.drop(created, 1), fn {_, _, %{"id" => id}} ->
               conn
               |> delete("/api/account/v1/user/tags/transaction/#{id}")
               |> response(200) == ""
             end)

      assert conn
             |> get("/api/account/v1/user/tags/transaction")
             |> json_response(200) == []

      assert Enum.all?(created, fn {addr, _, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/transaction/#{addr}")
                 |> json_response(200)

               response["personal_tx_tag"] == nil
             end)
    end

    test "post && get watchlist address", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map
        )
        |> doc(description: "Add address to watchlist")
        |> json_response(200)

      assert post_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert post_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert post_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert post_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]

      get_watchlist_address_response = conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

      assert get_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert get_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert get_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert get_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]
      assert get_watchlist_address_response["id"] == post_watchlist_address_response["id"]

      watchlist_address_map_1 = build(:watchlist_address)

      post_watchlist_address_response_1 =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map_1
        )
        |> json_response(200)

      get_watchlist_address_response_1_0 =
        conn
        |> get("/api/account/v1/user/watchlist")
        |> doc(description: "Get addresses from watchlists")
        |> json_response(200)
        |> Enum.at(0)

      get_watchlist_address_response_1_1 =
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(1)

      assert get_watchlist_address_response_1_0 == get_watchlist_address_response

      assert get_watchlist_address_response_1_1["notification_settings"] ==
               watchlist_address_map_1["notification_settings"]

      assert get_watchlist_address_response_1_1["name"] == watchlist_address_map_1["name"]

      assert get_watchlist_address_response_1_1["notification_methods"] ==
               watchlist_address_map_1["notification_methods"]

      assert get_watchlist_address_response_1_1["address_hash"] == watchlist_address_map_1["address_hash"]
      assert get_watchlist_address_response_1_1["id"] == post_watchlist_address_response_1["id"]
    end

    test "delete watchlist address", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map
        )
        |> json_response(200)

      assert post_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert post_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert post_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert post_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]

      get_watchlist_address_response = conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

      assert get_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert get_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert get_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert get_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]
      assert get_watchlist_address_response["id"] == post_watchlist_address_response["id"]

      watchlist_address_map_1 = build(:watchlist_address)

      post_watchlist_address_response_1 =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map_1
        )
        |> json_response(200)

      get_watchlist_address_response_1_0 =
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

      get_watchlist_address_response_1_1 =
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(1)

      assert get_watchlist_address_response_1_0 == get_watchlist_address_response

      assert get_watchlist_address_response_1_1["notification_settings"] ==
               watchlist_address_map_1["notification_settings"]

      assert get_watchlist_address_response_1_1["name"] == watchlist_address_map_1["name"]

      assert get_watchlist_address_response_1_1["notification_methods"] ==
               watchlist_address_map_1["notification_methods"]

      assert get_watchlist_address_response_1_1["address_hash"] == watchlist_address_map_1["address_hash"]
      assert get_watchlist_address_response_1_1["id"] == post_watchlist_address_response_1["id"]

      assert conn
             |> delete("/api/account/v1/user/watchlist/#{get_watchlist_address_response_1_1["id"]}")
             |> doc(description: "Delete address from watchlist by id")
             |> response(200) == ""

      assert conn
             |> delete("/api/account/v1/user/watchlist/#{get_watchlist_address_response_1_0["id"]}")
             |> response(200) == ""

      assert conn |> get("/api/account/v1/user/watchlist") |> json_response(200) == []
    end

    test "put watchlist address", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map
        )
        |> json_response(200)

      assert post_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert post_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert post_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert post_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]

      get_watchlist_address_response = conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

      assert get_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert get_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert get_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert get_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]
      assert get_watchlist_address_response["id"] == post_watchlist_address_response["id"]

      new_watchlist_address_map = build(:watchlist_address)

      put_watchlist_address_response =
        conn
        |> put(
          "/api/account/v1/user/watchlist/#{post_watchlist_address_response["id"]}",
          new_watchlist_address_map
        )
        |> doc(description: "Edit watchlist address")
        |> json_response(200)

      assert put_watchlist_address_response["notification_settings"] ==
               new_watchlist_address_map["notification_settings"]

      assert put_watchlist_address_response["name"] == new_watchlist_address_map["name"]
      assert put_watchlist_address_response["notification_methods"] == new_watchlist_address_map["notification_methods"]
      assert put_watchlist_address_response["address_hash"] == new_watchlist_address_map["address_hash"]
      assert get_watchlist_address_response["id"] == put_watchlist_address_response["id"]
    end

    test "cannot create duplicate of watchlist address", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          watchlist_address_map
        )
        |> json_response(200)

      assert post_watchlist_address_response["notification_settings"] == watchlist_address_map["notification_settings"]
      assert post_watchlist_address_response["name"] == watchlist_address_map["name"]
      assert post_watchlist_address_response["notification_methods"] == watchlist_address_map["notification_methods"]
      assert post_watchlist_address_response["address_hash"] == watchlist_address_map["address_hash"]

      assert conn
             |> post(
               "/api/account/v1/user/watchlist",
               watchlist_address_map
             )
             |> doc(description: "Example of error on creating watchlist address")
             |> json_response(422) == %{"errors" => %{"watchlist_id" => ["Address already added to the watchlist"]}}

      new_watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response_1 =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          new_watchlist_address_map
        )
        |> json_response(200)

      put_watchlist_address_response =
        conn
        |> put(
          "/api/account/v1/user/watchlist/#{post_watchlist_address_response_1["id"]}",
          watchlist_address_map
        )
        |> doc(description: "Example of error on editing watchlist address")
        |> json_response(422) == %{"errors" => %{"watchlist_id" => ["Address already added to the watchlist"]}}
    end

    test "post api key", %{conn: conn} do
      post_api_key_response =
        conn
        |> post(
          "/api/account/v1/user/api_keys",
          %{"name" => "test"}
        )
        |> doc(description: "Add api key")
        |> json_response(200)

      assert post_api_key_response["name"] == "test"
      assert post_api_key_response["api_key"]
    end

    test "can create not more than 3 api keys + get api keys", %{conn: conn} do
      Enum.each(0..2, fn _x ->
        conn
        |> post(
          "/api/account/v1/user/api_keys",
          %{"name" => "test"}
        )
        |> json_response(200)
      end)

      assert conn
             |> post(
               "/api/account/v1/user/api_keys",
               %{"name" => "test"}
             )
             |> doc(description: "Example of error on creating api key")
             |> json_response(422) == %{"errors" => %{"name" => ["Max 3 keys per account"]}}

      assert conn
             |> get("/api/account/v1/user/api_keys")
             |> doc(description: "Get api keys list")
             |> json_response(200)
             |> Enum.count() == 3
    end

    test "edit api key", %{conn: conn} do
      post_api_key_response =
        conn
        |> post(
          "/api/account/v1/user/api_keys",
          %{"name" => "test"}
        )
        |> json_response(200)

      assert post_api_key_response["name"] == "test"
      assert post_api_key_response["api_key"]

      put_api_key_response =
        conn
        |> put(
          "/api/account/v1/user/api_keys/#{post_api_key_response["api_key"]}",
          %{"name" => "test_1"}
        )
        |> doc(description: "Edit api key")
        |> json_response(200)

      assert put_api_key_response["api_key"] == post_api_key_response["api_key"]
      assert put_api_key_response["name"] == "test_1"

      assert conn
             |> get("/api/account/v1/user/api_keys")
             |> json_response(200) == [put_api_key_response]
    end

    test "delete api key", %{conn: conn} do
      post_api_key_response =
        conn
        |> post(
          "/api/account/v1/user/api_keys",
          %{"name" => "test"}
        )
        |> json_response(200)

      assert post_api_key_response["name"] == "test"
      assert post_api_key_response["api_key"]

      assert conn
             |> get("/api/account/v1/user/api_keys")
             |> json_response(200)
             |> Enum.count() == 1

      assert conn
             |> delete("/api/account/v1/user/api_keys/#{post_api_key_response["api_key"]}")
             |> doc(description: "Delete api key")
             |> response(200) == ""

      assert conn
             |> get("/api/account/v1/user/api_keys")
             |> json_response(200) == []
    end

    test "post custom abi", %{conn: conn} do
      custom_abi = build(:custom_abi)

      post_custom_abi_response =
        conn
        |> post(
          "/api/account/v1/user/custom_abis",
          custom_abi
        )
        |> doc(description: "Add custom abi")
        |> json_response(200)

      assert post_custom_abi_response["name"] == custom_abi["name"]
      assert post_custom_abi_response["abi"] == custom_abi["abi"]
      assert post_custom_abi_response["contract_address_hash"] == custom_abi["contract_address_hash"]
      assert post_custom_abi_response["id"]
    end

    test "can create not more than 15 custom abis + get custom abi", %{conn: conn} do
      Enum.each(0..14, fn _x ->
        conn
        |> post(
          "/api/account/v1/user/custom_abis",
          build(:custom_abi)
        )
        |> json_response(200)
      end)

      assert conn
             |> post(
               "/api/account/v1/user/custom_abis",
               build(:custom_abi)
             )
             |> doc(description: "Example of error on creating custom abi")
             |> json_response(422) == %{"errors" => %{"name" => ["Max 15 ABIs per account"]}}

      assert conn
             |> get("/api/account/v1/user/custom_abis")
             |> doc(description: "Get custom abis list")
             |> json_response(200)
             |> Enum.count() == 15
    end

    test "edit custom abi", %{conn: conn} do
      custom_abi = build(:custom_abi)

      post_custom_abi_response =
        conn
        |> post(
          "/api/account/v1/user/custom_abis",
          custom_abi
        )
        |> json_response(200)

      assert post_custom_abi_response["name"] == custom_abi["name"]
      assert post_custom_abi_response["abi"] == custom_abi["abi"]
      assert post_custom_abi_response["contract_address_hash"] == custom_abi["contract_address_hash"]
      assert post_custom_abi_response["id"]

      custom_abi_1 = build(:custom_abi)

      put_custom_abi_response =
        conn
        |> put(
          "/api/account/v1/user/custom_abis/#{post_custom_abi_response["id"]}",
          custom_abi_1
        )
        |> doc(description: "Edit custom abi")
        |> json_response(200)

      assert put_custom_abi_response["name"] == custom_abi_1["name"]
      assert put_custom_abi_response["id"] == post_custom_abi_response["id"]
      assert put_custom_abi_response["contract_address_hash"] == custom_abi_1["contract_address_hash"]
      assert put_custom_abi_response["abi"] == custom_abi_1["abi"]

      assert conn
             |> get("/api/account/v1/user/custom_abis")
             |> json_response(200) == [put_custom_abi_response]
    end

    test "delete custom abi", %{conn: conn} do
      custom_abi = build(:custom_abi)

      post_custom_abi_response =
        conn
        |> post(
          "/api/account/v1/user/custom_abis",
          custom_abi
        )
        |> json_response(200)

      assert post_custom_abi_response["name"] == custom_abi["name"]
      assert post_custom_abi_response["id"]

      assert conn
             |> get("/api/account/v1/user/custom_abis")
             |> json_response(200)
             |> Enum.count() == 1

      assert conn
             |> delete("/api/account/v1/user/custom_abis/#{post_custom_abi_response["id"]}")
             |> doc(description: "Delete custom abi")
             |> response(200) == ""

      assert conn
             |> get("/api/account/v1/user/custom_abis")
             |> json_response(200) == []
    end
  end
end
