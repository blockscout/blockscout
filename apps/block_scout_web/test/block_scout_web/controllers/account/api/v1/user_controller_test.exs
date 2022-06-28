defmodule BlockScoutWeb.Account.Api.V1.UserControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Guardian
  alias BlockScoutWeb.Models.UserFromAuth

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end

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

    test "post private address tag", %{conn: conn, user: user} do
      tag_address_response =
        conn
        |> post("/api/account/v1/user/tags/address", %{
          "address_hash" => "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b",
          "name" => "MyName"
        })
        |> doc(description: "Create private address tag")
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

      Enum.all?(created, fn {_, _, %{"id" => id}} ->
        conn
        |> delete("/api/account/v1/user/tags/address/#{id}")
        |> response(200) == ""
      end)

      assert conn
             |> get("/api/account/v1/user/tags/address")
             |> json_response(200) == []

      assert Enum.all?(created, fn {addr, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/address/#{addr}")
                 |> json_response(200)

               response["personal_tags"] == []
             end)
    end

    test "post private transaction tag", %{conn: conn, user: user} do
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

      Enum.all?(created, fn {_, _, %{"id" => id}} ->
        conn
        |> delete("/api/account/v1/user/tags/transaction/#{id}")
        |> response(200) == ""
      end)

      assert conn
             |> get("/api/account/v1/user/tags/transaction")
             |> json_response(200) == []

      assert Enum.all?(created, fn {addr, map_tag, _} ->
               response =
                 conn
                 |> get("/api/account/v1/tags/transaction/#{addr}")
                 |> json_response(200)

               response["personal_tx_tag"] == nil
             end)
    end

    test "post watchlist", %{conn: conn} do
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
    end


    #"{\"errors\":{\"watchlist_id\":[\"Address already added to the watchlist\"]}}"

    # add check for exchange rate and address balance on watchlist response

    # response =
    #   conn
    #   |> get("/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b")
    #   # |> doc(description: "Get tags for address") # call doc only when all the fields will be filled (private tags, watchlist_names, public tags)
    #   |> json_response(200)

    # assert response["personal_tags"] == [%{"display_name" => "MyName", "label" => "MyName"}]

    # test "get private address tags", %{conn: conn} do
    #   conn
    #   |> post("api/account/v1/user/tags/address", %{
    #     "address_hash" => "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b",
    #     "name" => "MyName"
    #   })
    #   |> json_response(200)

    #   response =
    #     conn
    #     |> get("/api/account/v1/user/tags/address")
    #     |> json_response(200)

    #   # [%{"address_hash" => "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b", "id" => 9, "name" => "MyName"}]
    # end

    test "get api/account/v1/user/tags/address", %{conn: conn} do
      result_conn =
        conn
        |> get("/api/account/v1/user/tags/address/")

      # |> doc()

      assert result_conn.status == 200
    end
  end
end
