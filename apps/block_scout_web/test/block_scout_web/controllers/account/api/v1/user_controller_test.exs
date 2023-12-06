defmodule BlockScoutWeb.Account.Api.V1.UserControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Account.{
    TagAddress,
    TagTransaction,
    WatchlistAddress
  }

  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias BlockScoutWeb.Models.UserFromAuth

  setup %{conn: conn} do
    auth = build(:auth)

    {:ok, user} = UserFromAuth.find_or_create(auth)

    {:ok, user: user, conn: Plug.Test.init_test_session(conn, current_user: user)}
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

    test "can't insert private address tags more than limit", %{conn: conn, user: user} do
      old_env = Application.get_env(:explorer, Explorer.Account)

      new_env =
        old_env
        |> Keyword.replace(:private_tags_limit, 5)
        |> Keyword.replace(:watchlist_addresses_limit, 5)

      Application.put_env(:explorer, Explorer.Account, new_env)

      for _ <- 0..3 do
        build(:tag_address_db, user: user) |> Repo.account_repo().insert()
      end

      assert conn
             |> post("/api/account/v1/user/tags/address", build(:tag_address))
             |> json_response(200)

      assert conn
             |> post("/api/account/v1/user/tags/address", build(:tag_address))
             |> json_response(422)

      Application.put_env(:explorer, Explorer.Account, old_env)
    end

    test "check address tags pagination", %{conn: conn, user: user} do
      tags_address =
        for _ <- 0..50 do
          build(:tag_address_db, user: user) |> Repo.account_repo().insert!()
        end

      assert response =
               conn
               |> get("/api/account/v2/user/tags/address")
               |> json_response(200)

      response_1 =
        conn
        |> get("/api/account/v2/user/tags/address", response["next_page_params"])
        |> json_response(200)

      check_paginated_response(response, response_1, tags_address)
    end

    test "edit private address tag", %{conn: conn} do
      address_tag = build(:tag_address)

      tag_address_response =
        conn
        |> post("/api/account/v1/user/tags/address", address_tag)
        |> json_response(200)

      _response =
        conn
        |> get("/api/account/v1/user/tags/address")
        |> json_response(200) == [tag_address_response]

      assert tag_address_response["address_hash"] == address_tag["address_hash"]
      assert tag_address_response["name"] == address_tag["name"]
      assert tag_address_response["id"]

      new_address_tag = build(:tag_address)

      new_tag_address_response =
        conn
        |> put("/api/account/v1/user/tags/address/#{tag_address_response["id"]}", new_address_tag)
        |> doc(description: "Edit private address tag")
        |> json_response(200)

      assert new_tag_address_response["address_hash"] == new_address_tag["address_hash"]
      assert new_tag_address_response["name"] == new_address_tag["name"]
      assert new_tag_address_response["id"] == tag_address_response["id"]
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

          {addr, %{"display_name" => name, "label" => name, "address_hash" => addr},
           %{
             "address_hash" => addr,
             "id" => id,
             "name" => name,
             "address" => %{
               "hash" => Address.checksum(addr),
               "implementation_name" => nil,
               "is_contract" => false,
               "is_verified" => false,
               "name" => nil,
               "private_tags" => [],
               "public_tags" => [],
               "watchlist_names" => []
             }
           }}
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

          {addr, %{"display_name" => name, "label" => name, "address_hash" => addr},
           %{
             "address_hash" => addr,
             "id" => id,
             "name" => name,
             "address" => %{
               "hash" => Address.checksum(addr),
               "implementation_name" => nil,
               "is_contract" => false,
               "is_verified" => false,
               "name" => nil,
               "private_tags" => [],
               "public_tags" => [],
               "watchlist_names" => []
             }
           }}
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
             |> json_response(200) == %{"message" => "OK"}

      assert Enum.all?(Enum.drop(created, 1), fn {_, _, %{"id" => id}} ->
               conn
               |> delete("/api/account/v1/user/tags/address/#{id}")
               |> json_response(200) == %{"message" => "OK"}
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

    test "can't insert private transaction tags more than limit", %{conn: conn, user: user} do
      old_env = Application.get_env(:explorer, Explorer.Account)

      new_env =
        old_env
        |> Keyword.replace(:private_tags_limit, 5)
        |> Keyword.replace(:watchlist_addresses_limit, 5)

      Application.put_env(:explorer, Explorer.Account, new_env)

      for _ <- 0..3 do
        build(:tag_transaction_db, user: user) |> Repo.account_repo().insert()
      end

      assert conn
             |> post("/api/account/v1/user/tags/transaction", build(:tag_transaction))
             |> json_response(200)

      assert conn
             |> post("/api/account/v1/user/tags/transaction", build(:tag_transaction))
             |> json_response(422)

      Application.put_env(:explorer, Explorer.Account, old_env)
    end

    test "check transaction tags pagination", %{conn: conn, user: user} do
      tags_address =
        for _ <- 0..50 do
          build(:tag_transaction_db, user: user) |> Repo.account_repo().insert!()
        end

      assert response =
               conn
               |> get("/api/account/v2/user/tags/transaction")
               |> json_response(200)

      response_1 =
        conn
        |> get("/api/account/v2/user/tags/transaction", response["next_page_params"])
        |> json_response(200)

      check_paginated_response(response, response_1, tags_address)
    end

    test "edit private transaction tag", %{conn: conn} do
      tx_tag = build(:tag_transaction)

      tag_response =
        conn
        |> post("/api/account/v1/user/tags/transaction", tx_tag)
        |> json_response(200)

      _response =
        conn
        |> get("/api/account/v1/user/tags/transaction")
        |> json_response(200) == [tag_response]

      assert tag_response["address_hash"] == tx_tag["address_hash"]
      assert tag_response["name"] == tx_tag["name"]
      assert tag_response["id"]

      new_tx_tag = build(:tag_transaction)

      new_tag_response =
        conn
        |> put("/api/account/v1/user/tags/transaction/#{tag_response["id"]}", new_tx_tag)
        |> doc(description: "Edit private transaction tag")
        |> json_response(200)

      assert new_tag_response["address_hash"] == new_tx_tag["address_hash"]
      assert new_tag_response["name"] == new_tx_tag["name"]
      assert new_tag_response["id"] == tag_response["id"]
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
             |> json_response(200) == %{"message" => "OK"}

      assert Enum.all?(Enum.drop(created, 1), fn {_, _, %{"id" => id}} ->
               conn
               |> delete("/api/account/v1/user/tags/transaction/#{id}")
               |> json_response(200) == %{"message" => "OK"}
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
        |> doc(description: "Add address to watch list")
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
        |> Enum.at(1)

      get_watchlist_address_response_1_1 =
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

      assert get_watchlist_address_response_1_0 == get_watchlist_address_response

      assert get_watchlist_address_response_1_1["notification_settings"] ==
               watchlist_address_map_1["notification_settings"]

      assert get_watchlist_address_response_1_1["name"] == watchlist_address_map_1["name"]

      assert get_watchlist_address_response_1_1["notification_methods"] ==
               watchlist_address_map_1["notification_methods"]

      assert get_watchlist_address_response_1_1["address_hash"] == watchlist_address_map_1["address_hash"]
      assert get_watchlist_address_response_1_1["id"] == post_watchlist_address_response_1["id"]
    end

    test "can't insert watchlist addresses more than limit", %{conn: conn, user: user} do
      old_env = Application.get_env(:explorer, Explorer.Account)

      new_env =
        old_env
        |> Keyword.replace(:private_tags_limit, 5)
        |> Keyword.replace(:watchlist_addresses_limit, 5)

      Application.put_env(:explorer, Explorer.Account, new_env)

      for _ <- 0..3 do
        build(:watchlist_address_db, wl_id: user.watchlist_id) |> Repo.account_repo().insert()
      end

      assert conn
             |> post("/api/account/v1/user/watchlist", build(:watchlist_address))
             |> json_response(200)

      assert conn
             |> post("/api/account/v1/user/watchlist", build(:watchlist_address))
             |> json_response(422)

      Application.put_env(:explorer, Explorer.Account, old_env)
    end

    test "check watchlist tags pagination", %{conn: conn, user: user} do
      tags_address =
        for _ <- 0..50 do
          build(:watchlist_address_db, wl_id: user.watchlist_id) |> Repo.account_repo().insert!()
        end

      assert response =
               conn
               |> get("/api/account/v2/user/watchlist")
               |> json_response(200)

      response_1 =
        conn
        |> get("/api/account/v2/user/watchlist", response["next_page_params"])
        |> json_response(200)

      check_paginated_response(response, response_1, tags_address)
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
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(1)

      get_watchlist_address_response_1_1 =
        conn |> get("/api/account/v1/user/watchlist") |> json_response(200) |> Enum.at(0)

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
             |> json_response(200) == %{"message" => "OK"}

      assert conn
             |> delete("/api/account/v1/user/watchlist/#{get_watchlist_address_response_1_0["id"]}")
             |> json_response(200) == %{"message" => "OK"}

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
             |> json_response(422) == %{"errors" => %{"watchlist_id" => ["Address already added to the watch list"]}}

      new_watchlist_address_map = build(:watchlist_address)

      post_watchlist_address_response_1 =
        conn
        |> post(
          "/api/account/v1/user/watchlist",
          new_watchlist_address_map
        )
        |> json_response(200)

      assert conn
             |> put(
               "/api/account/v1/user/watchlist/#{post_watchlist_address_response_1["id"]}",
               watchlist_address_map
             )
             |> doc(description: "Example of error on editing watchlist address")
             |> json_response(422) == %{"errors" => %{"watchlist_id" => ["Address already added to the watch list"]}}
    end

    test "watchlist address returns with token balances info", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      conn
      |> post(
        "/api/account/v1/user/watchlist",
        watchlist_address_map
      )
      |> json_response(200)

      watchlist_address_map_1 = build(:watchlist_address)

      conn
      |> post(
        "/api/account/v1/user/watchlist",
        watchlist_address_map_1
      )
      |> json_response(200)

      values =
        for _i <- 0..149 do
          ctb =
            insert(:address_current_token_balance_with_token_id,
              address: Repo.get_by(Address, hash: watchlist_address_map["address_hash"])
            )
            |> Repo.preload([:token])

          Decimal.div(
            Decimal.mult(ctb.value, ctb.token.fiat_value),
            Decimal.new(10 ** Decimal.to_integer(ctb.token.decimals))
          )
        end

      values_1 =
        for _i <- 0..200 do
          ctb =
            insert(:address_current_token_balance_with_token_id,
              address: Repo.get_by(Address, hash: watchlist_address_map_1["address_hash"])
            )
            |> Repo.preload([:token])

          Decimal.div(
            Decimal.mult(ctb.value, ctb.token.fiat_value),
            Decimal.new(10 ** Decimal.to_integer(ctb.token.decimals))
          )
        end
        |> Enum.sort(fn x1, x2 -> Decimal.compare(x1, x2) in [:gt, :eq] end)
        |> Enum.take(150)

      [wa2, wa1] = conn |> get("/api/account/v1/user/watchlist") |> json_response(200)

      assert wa1["tokens_fiat_value"] |> Decimal.new() |> Decimal.round(13) ==
               values |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(x, acc) end) |> Decimal.round(13)

      assert wa1["tokens_count"] == 150
      assert wa1["tokens_overflow"] == false

      assert wa2["tokens_fiat_value"] |> Decimal.new() |> Decimal.round(13) ==
               values_1 |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(x, acc) end) |> Decimal.round(13)

      assert wa2["tokens_count"] == 150
      assert wa2["tokens_overflow"] == true
    end

    test "watchlist address returns with token balances info + handle nil fiat values", %{conn: conn} do
      watchlist_address_map = build(:watchlist_address)

      conn
      |> post(
        "/api/account/v1/user/watchlist",
        watchlist_address_map
      )
      |> json_response(200)

      values =
        for _i <- 0..148 do
          ctb =
            insert(:address_current_token_balance_with_token_id,
              address: Repo.get_by(Address, hash: watchlist_address_map["address_hash"])
            )
            |> Repo.preload([:token])

          Decimal.div(
            Decimal.mult(ctb.value, ctb.token.fiat_value),
            Decimal.new(10 ** Decimal.to_integer(ctb.token.decimals))
          )
        end

      token = insert(:token, fiat_value: nil)

      insert(:address_current_token_balance_with_token_id,
        address: Repo.get_by(Address, hash: watchlist_address_map["address_hash"]),
        token: token,
        token_contract_address_hash: token.contract_address_hash
      )

      [wa1] = conn |> get("/api/account/v1/user/watchlist") |> json_response(200)

      assert wa1["tokens_fiat_value"] |> Decimal.new() |> Decimal.round(13) ==
               values |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(x, acc) end) |> Decimal.round(13)

      assert wa1["tokens_count"] == 150
      assert wa1["tokens_overflow"] == false
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
             |> json_response(200) == %{"message" => "OK"}

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
             |> json_response(200) == %{"message" => "OK"}

      assert conn
             |> get("/api/account/v1/user/custom_abis")
             |> json_response(200) == []
    end
  end

  describe "public tags" do
    test "create public tags request", %{conn: conn} do
      public_tags_request = build(:public_tags_request)

      post_public_tags_request_response =
        conn
        |> post(
          "/api/account/v1/user/public_tags",
          public_tags_request
        )
        |> doc(description: "Submit request to add a public tag")
        |> json_response(200)

      assert post_public_tags_request_response["full_name"] == public_tags_request["full_name"]
      assert post_public_tags_request_response["email"] == public_tags_request["email"]
      assert post_public_tags_request_response["tags"] == public_tags_request["tags"]
      assert post_public_tags_request_response["website"] == public_tags_request["website"]
      assert post_public_tags_request_response["additional_comment"] == public_tags_request["additional_comment"]
      assert post_public_tags_request_response["addresses"] == public_tags_request["addresses"]
      assert post_public_tags_request_response["company"] == public_tags_request["company"]
      assert post_public_tags_request_response["is_owner"] == public_tags_request["is_owner"]
      assert post_public_tags_request_response["id"]
    end

    test "get one public tags requests", %{conn: conn} do
      public_tags_request = build(:public_tags_request)

      post_public_tags_request_response =
        conn
        |> post(
          "/api/account/v1/user/public_tags",
          public_tags_request
        )
        |> json_response(200)

      assert post_public_tags_request_response["full_name"] == public_tags_request["full_name"]
      assert post_public_tags_request_response["email"] == public_tags_request["email"]
      assert post_public_tags_request_response["tags"] == public_tags_request["tags"]
      assert post_public_tags_request_response["website"] == public_tags_request["website"]
      assert post_public_tags_request_response["additional_comment"] == public_tags_request["additional_comment"]
      assert post_public_tags_request_response["addresses"] == public_tags_request["addresses"]
      assert post_public_tags_request_response["company"] == public_tags_request["company"]
      assert post_public_tags_request_response["is_owner"] == public_tags_request["is_owner"]
      assert post_public_tags_request_response["id"]

      assert conn
             |> get("/api/account/v1/user/public_tags")
             |> json_response(200)
             |> Enum.map(&convert_date/1) ==
               [post_public_tags_request_response]
               |> Enum.map(&convert_date/1)
    end

    test "get and delete several public tags requests", %{conn: conn} do
      public_tags_list = build_list(10, :public_tags_request)

      final_list =
        public_tags_list
        |> Enum.map(fn request ->
          response =
            conn
            |> post(
              "/api/account/v1/user/public_tags",
              request
            )
            |> json_response(200)

          assert response["full_name"] == request["full_name"]
          assert response["email"] == request["email"]
          assert response["tags"] == request["tags"]
          assert response["website"] == request["website"]
          assert response["additional_comment"] == request["additional_comment"]
          assert response["addresses"] == request["addresses"]
          assert response["company"] == request["company"]
          assert response["is_owner"] == request["is_owner"]
          assert response["id"]

          convert_date(response)
        end)
        |> Enum.reverse()

      assert conn
             |> get("/api/account/v1/user/public_tags")
             |> doc(description: "Get list of requests to add a public tag")
             |> json_response(200)
             |> Enum.map(&convert_date/1) == final_list

      %{"id" => id} = Enum.at(final_list, 0)

      assert conn
             |> delete("/api/account/v1/user/public_tags/#{id}", %{"remove_reason" => "reason"})
             |> doc(description: "Delete public tags request")
             |> json_response(200) == %{"message" => "OK"}

      Enum.each(Enum.drop(final_list, 1), fn request ->
        assert conn
               |> delete("/api/account/v1/user/public_tags/#{request["id"]}", %{"remove_reason" => "reason"})
               |> json_response(200) == %{"message" => "OK"}
      end)

      assert conn
             |> get("/api/account/v1/user/public_tags")
             |> json_response(200) == []
    end

    test "edit public tags request", %{conn: conn} do
      public_tags_request = build(:public_tags_request)

      post_public_tags_request_response =
        conn
        |> post(
          "/api/account/v1/user/public_tags",
          public_tags_request
        )
        |> json_response(200)

      assert post_public_tags_request_response["full_name"] == public_tags_request["full_name"]
      assert post_public_tags_request_response["email"] == public_tags_request["email"]
      assert post_public_tags_request_response["tags"] == public_tags_request["tags"]
      assert post_public_tags_request_response["website"] == public_tags_request["website"]
      assert post_public_tags_request_response["additional_comment"] == public_tags_request["additional_comment"]
      assert post_public_tags_request_response["addresses"] == public_tags_request["addresses"]
      assert post_public_tags_request_response["company"] == public_tags_request["company"]
      assert post_public_tags_request_response["is_owner"] == public_tags_request["is_owner"]
      assert post_public_tags_request_response["id"]

      assert conn
             |> get("/api/account/v1/user/public_tags")
             |> json_response(200)
             |> Enum.map(&convert_date/1) ==
               [post_public_tags_request_response]
               |> Enum.map(&convert_date/1)

      new_public_tags_request = build(:public_tags_request)

      put_public_tags_request_response =
        conn
        |> put(
          "/api/account/v1/user/public_tags/#{post_public_tags_request_response["id"]}",
          new_public_tags_request
        )
        |> doc(description: "Edit request to add a public tag")
        |> json_response(200)

      assert put_public_tags_request_response["full_name"] == new_public_tags_request["full_name"]
      assert put_public_tags_request_response["email"] == new_public_tags_request["email"]
      assert put_public_tags_request_response["tags"] == new_public_tags_request["tags"]
      assert put_public_tags_request_response["website"] == new_public_tags_request["website"]
      assert put_public_tags_request_response["additional_comment"] == new_public_tags_request["additional_comment"]
      assert put_public_tags_request_response["addresses"] == new_public_tags_request["addresses"]
      assert put_public_tags_request_response["company"] == new_public_tags_request["company"]
      assert put_public_tags_request_response["is_owner"] == new_public_tags_request["is_owner"]
      assert put_public_tags_request_response["id"] == post_public_tags_request_response["id"]

      assert conn
             |> get("/api/account/v1/user/public_tags")
             |> json_response(200)
             |> Enum.map(&convert_date/1) ==
               [put_public_tags_request_response]
               |> Enum.map(&convert_date/1)
    end
  end

  def convert_date(request) do
    {:ok, time, _} = DateTime.from_iso8601(request["submission_date"])
    %{request | "submission_date" => Calendar.strftime(time, "%b %d, %Y")}
  end

  defp compare_item(%TagAddress{} = tag_address, json) do
    assert json["address_hash"] == to_string(tag_address.address_hash)
    assert json["name"] == tag_address.name
    assert json["id"] == tag_address.id
    assert json["address"]["hash"] == Address.checksum(tag_address.address_hash)
  end

  defp compare_item(%TagTransaction{} = tag_transaction, json) do
    assert json["transaction_hash"] == to_string(tag_transaction.tx_hash)
    assert json["name"] == tag_transaction.name
    assert json["id"] == tag_transaction.id
  end

  defp compare_item(%WatchlistAddress{} = watchlist, json) do
    notification_settings = %{
      "native" => %{
        "incoming" => watchlist.watch_coin_input,
        "outcoming" => watchlist.watch_coin_output
      },
      "ERC-20" => %{
        "incoming" => watchlist.watch_erc_20_input,
        "outcoming" => watchlist.watch_erc_20_output
      },
      "ERC-721" => %{
        "incoming" => watchlist.watch_erc_721_input,
        "outcoming" => watchlist.watch_erc_721_output
      }
    }

    assert json["address_hash"] == to_string(watchlist.address_hash)
    assert json["name"] == watchlist.name
    assert json["id"] == watchlist.id
    assert json["address"]["hash"] == Address.checksum(watchlist.address_hash)
    assert json["notification_methods"]["email"] == watchlist.notify_email
    assert json["notification_settings"] == notification_settings
  end

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end
end
