defmodule BlockScoutWeb.AddressTokenBalanceController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressView, only: [from_address_hash: 1]
  alias BlockScoutWeb.AccessHelpers
  alias Explorer.{Chain, CustomContractsHelpers, Market}
  alias Indexer.Fetcher.TokenBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      token_balances =
        address_hash
        |> Chain.fetch_last_token_balances()

      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash, token_balances)
      end)

      circles_addresses_list = CustomContractsHelpers.get_custom_addresses_list(:circles_addresses)

      token_balances_with_price =
        token_balances
        |> Market.add_price()

      token_balances_except_bridged =
        token_balances
        |> Enum.filter(fn token_balance -> !token_balance.token.bridged end)

      circles_total_balance =
        if Enum.count(circles_addresses_list) > 0 do
          token_balances_except_bridged
          |> Enum.reduce(Decimal.new(0), fn token_balance, acc_balance ->
            {:ok, token_address} = Chain.hash_to_address(token_balance.address_hash)

            from_address = from_address_hash(token_address)

            created_from_address_hash =
              if from_address,
                do: "0x" <> Base.encode16(from_address.bytes, case: :lower),
                else: nil

            if Enum.member?(circles_addresses_list, created_from_address_hash) && token_balance.token.name == "Circles" &&
                 token_balance.token.symbol == "CRC" do
              Decimal.add(acc_balance, token_balance.value)
            else
              acc_balance
            end
          end)
        else
          Decimal.new(0)
        end

      case AccessHelpers.restricted_access?(address_hash_string, params) do
        {:ok, false} ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html",
            address_hash: address_hash,
            token_balances: token_balances_with_price,
            circles_total_balance: circles_total_balance
          )

        _ ->
          conn
          |> put_status(200)
          |> put_layout(false)
          |> render("_token_balances.html",
            address_hash: address_hash,
            token_balances: [],
            circles_total_balance: Decimal.new(0)
          )
      end
    else
      _ ->
        not_found(conn)
    end
  end
end
