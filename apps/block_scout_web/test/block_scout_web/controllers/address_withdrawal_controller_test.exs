defmodule BlockScoutWeb.AddressWithdrawalControllerTest do
  use BlockScoutWeb.ConnCase, async: true
  use ExUnit.Case, async: false

  import BlockScoutWeb.Routers.WebRouter.Helpers, only: [address_withdrawal_path: 3, address_withdrawal_path: 4]
  import BlockScoutWeb.WeiHelper, only: [format_wei_value: 2]
  import Mox

  alias Explorer.Chain.Address
  alias Explorer.Market.Token

  setup :verify_on_exit!

  describe "GET index/2" do
    setup :set_mox_global

    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_withdrawal_path(conn, :index, "invalid_address"))

      assert html_response(conn, 422)
    end

    if Application.compile_env(:explorer, :chain_type) !== :rsk do
      test "with valid address hash without address in the DB", %{conn: conn} do
        conn =
          get(
            conn,
            address_withdrawal_path(conn, :index, Address.checksum("0x8bf38d4764929064f2d4d3a56520a76ab3df415b"), %{
              "type" => "JSON"
            })
          )

        assert json_response(conn, 200)
        tiles = json_response(conn, 200)["items"]
        assert tiles |> length() == 0
      end
    end

    test "returns withdrawals for the address", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(30, :withdrawal))

      # to check that we can correctly render address overview
      get(conn, address_withdrawal_path(conn, :index, Address.checksum(address)))

      conn = get(conn, address_withdrawal_path(conn, :index, Address.checksum(address), %{"type" => "JSON"}))

      tiles = json_response(conn, 200)["items"]
      indexes = Enum.map(address.withdrawals, &to_string(&1.index))

      assert Enum.all?(indexes, fn index ->
               Enum.any?(tiles, &String.contains?(&1, index))
             end)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_withdrawal_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns next page of results based on last seen withdrawal", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(60, :withdrawal))

      {first_page, second_page} =
        address.withdrawals
        |> Enum.sort(&(&1.index >= &2.index))
        |> Enum.split(51)

      conn =
        get(conn, address_withdrawal_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), %{
          "index" => first_page |> List.last() |> (& &1.index).() |> Integer.to_string(),
          "type" => "JSON"
        })

      tiles = json_response(conn, 200)["items"]

      assert Enum.all?(second_page, fn withdrawal ->
               Enum.any?(tiles, fn tile ->
                 # more strict check since simple index could occur in the tile accidentally
                 String.contains?(tile, to_string(withdrawal.index)) and
                   String.contains?(tile, to_string(withdrawal.validator_index)) and
                   String.contains?(tile, to_string(withdrawal.block.number)) and
                   String.contains?(tile, format_wei_value(withdrawal.amount, :ether))
               end)
             end)

      refute Enum.any?(first_page, fn withdrawal ->
               Enum.any?(tiles, fn tile ->
                 # more strict check since simple index could occur in the tile accidentally
                 String.contains?(tile, to_string(withdrawal.index)) and
                   String.contains?(tile, to_string(withdrawal.validator_index)) and
                   String.contains?(tile, to_string(withdrawal.block.number)) and
                   String.contains?(tile, format_wei_value(withdrawal.amount, :ether))
               end)
             end)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(51, :withdrawal))

      conn = get(conn, address_withdrawal_path(conn, :index, Address.checksum(address.hash), %{"type" => "JSON"}))

      assert json_response(conn, 200)["next_page_path"]
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(1, :withdrawal))

      conn = get(conn, address_withdrawal_path(conn, :index, Address.checksum(address.hash), %{"type" => "JSON"}))

      refute json_response(conn, 200)["next_page_path"]
    end
  end
end
