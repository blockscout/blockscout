defmodule BlockScoutWeb.AddressCoinBalanceByDayController do
  @moduledoc """
  Manages the grouping by day of the coin balance history of an address
  """

  use BlockScoutWeb, :controller

  alias Explorer.Chain

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      balances_by_day = Chain.address_to_balances_by_day(address_hash)

      json(conn, balances_by_day)
    end
  end
end
