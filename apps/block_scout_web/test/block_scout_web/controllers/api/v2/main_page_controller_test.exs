defmodule BlockScoutWeb.API.V2.MainPageControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.WatchlistAddress
  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.Repo

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())

    :ok
  end

  describe "/main-page/blocks" do
    test "get empty list when no blocks", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/blocks")
      assert [] = json_response(request, 200)
    end

    test "get last 4 blocks", %{conn: conn} do
      blocks = insert_list(10, :block) |> Enum.take(-4) |> Enum.reverse()

      request = get(conn, "/api/v2/main-page/blocks")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 4

      for i <- 0..3 do
        compare_item(Enum.at(blocks, i), Enum.at(response, i))
      end
    end
  end

  describe "/main-page/transactions" do
    test "get empty list when no txs", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/transactions")
      assert [] = json_response(request, 200)
    end

    test "get last 6 txs", %{conn: conn} do
      txs = insert_list(10, :transaction) |> with_block() |> Enum.take(-6) |> Enum.reverse()

      request = get(conn, "/api/v2/main-page/transactions")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 6

      for i <- 0..5 do
        compare_item(Enum.at(txs, i), Enum.at(response, i))
      end
    end
  end

  describe "/main-page/transactions/watchlist" do
    test "unauthorized", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/transactions/watchlist")
      assert %{"message" => "Unauthorized"} = json_response(request, 401)
    end

    test "get last 6 txs", %{conn: conn} do
      txs = insert_list(10, :transaction) |> with_block()

      auth = build(:auth)
      {:ok, user} = UserFromAuth.find_or_create(auth)

      conn = Plug.Test.init_test_session(conn, current_user: user)

      address_1 = insert(:address)

      watchlist_address_1 =
        Repo.account_repo().insert!(%WatchlistAddress{
          name: "wallet_1",
          watchlist_id: user.watchlist_id,
          address_hash: address_1.hash,
          address_hash_hash: hash_to_lower_case_string(address_1.hash),
          watch_coin_input: true,
          watch_coin_output: true,
          watch_erc_20_input: true,
          watch_erc_20_output: true,
          watch_erc_721_input: true,
          watch_erc_721_output: true,
          watch_erc_1155_input: true,
          watch_erc_1155_output: true,
          notify_email: true
        })

      address_2 = insert(:address)

      watchlist_address_2 =
        Repo.account_repo().insert!(%WatchlistAddress{
          name: "wallet_2",
          watchlist_id: user.watchlist_id,
          address_hash: address_2.hash,
          address_hash_hash: hash_to_lower_case_string(address_2.hash),
          watch_coin_input: true,
          watch_coin_output: true,
          watch_erc_20_input: true,
          watch_erc_20_output: true,
          watch_erc_721_input: true,
          watch_erc_721_output: true,
          watch_erc_1155_input: true,
          watch_erc_1155_output: true,
          notify_email: true
        })

      txs_1 = insert_list(2, :transaction, from_address: address_1) |> with_block()
      txs_2 = insert_list(1, :transaction, from_address: address_2, to_address: address_1) |> with_block()
      txs_3 = insert_list(3, :transaction, to_address: address_2) |> with_block()
      txs = (txs_1 ++ txs_2 ++ txs_3) |> Enum.reverse()

      request = get(conn, "/api/v2/main-page/transactions/watchlist")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 6

      for i <- 0..5 do
        compare_item(Enum.at(txs, i), Enum.at(response, i), %{
          address_1.hash => watchlist_address_1.name,
          address_2.hash => watchlist_address_2.name
        })
      end
    end
  end

  describe "/main-page/indexing-status" do
    test "get indexing status", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/indexing-status")
      assert request = json_response(request, 200)

      assert Map.has_key?(request, "finished_indexing_blocks")
      assert Map.has_key?(request, "finished_indexing")
      assert Map.has_key?(request, "indexed_blocks_ratio")
      assert Map.has_key?(request, "indexed_internal_transactions_ratio")
    end
  end

  defp compare_item(%Block{} = block, json) do
    assert to_string(block.hash) == json["hash"]
    assert block.number == json["height"]
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%Transaction{} = transaction, json, wl_names) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]

    assert json["to"]["watchlist_names"] ==
             if(wl_names[transaction.to_address_hash],
               do: [
                 %{
                   "display_name" => wl_names[transaction.to_address_hash],
                   "label" => wl_names[transaction.to_address_hash]
                 }
               ],
               else: []
             )

    assert json["from"]["watchlist_names"] ==
             if(wl_names[transaction.from_address_hash],
               do: [
                 %{
                   "display_name" => wl_names[transaction.from_address_hash],
                   "label" => wl_names[transaction.from_address_hash]
                 }
               ],
               else: []
             )
  end
end
