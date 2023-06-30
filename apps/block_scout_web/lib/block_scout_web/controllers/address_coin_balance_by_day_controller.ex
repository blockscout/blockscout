defmodule BlockScoutWeb.AddressCoinBalanceByDayController do
  @moduledoc """
  Manages the grouping by day of the coin balance history of an address
  """

  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      balances_by_day =
        address_hash
        |> Chain.address_to_balances_by_day()
        |> Enum.map(fn %{value: value} = map ->
          Map.put(map, :value, Decimal.to_float(value))
        end)

      json(conn, balances_by_day)
    else
      _ ->
        not_found(conn)
    end
  end
end
