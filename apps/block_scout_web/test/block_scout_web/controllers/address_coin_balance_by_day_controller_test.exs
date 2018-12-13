defmodule BlockScoutWeb.AddressCoinBalanceByDayControllerTest do
  use BlockScoutWeb.ConnCase

  describe "GET index/2" do
    test "returns the coin balance history grouped by date", %{conn: conn} do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1))
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_day_ago.number)

      conn = get(conn, address_coin_balance_by_day_path(conn, :index, address), %{"type" => "JSON"})

      response = json_response(conn, 200)

      assert length(response) == 2
    end
  end
end
