defmodule BlockScoutWeb.AddressCoinBalanceByDayControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Address

  describe "GET index/2" do
    test "returns the coin balance history grouped by date", %{conn: conn} do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon, number: 2)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1), number: 1)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_day_ago.number)
      insert(:fetched_balance_daily, address_hash: address.hash, value: 1000, day: noon)
      insert(:fetched_balance_daily, address_hash: address.hash, value: 2000, day: Timex.shift(noon, days: -1))

      conn = get(conn, address_coin_balance_by_day_path(conn, :index, Address.checksum(address)), %{"type" => "JSON"})

      response = json_response(conn, 200)

      assert [
               %{"date" => _, "value" => 2.0e-15},
               %{"date" => _, "value" => 1.0e-15}
             ] = response
    end
  end
end
