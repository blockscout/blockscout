defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  def index(conn, params) do
    addresses =
      params
      |> paging_options()
      |> Chain.list_top_addresses()

    {addresses_page, next_page} = split_list_by_page(addresses)

    cur_page_number =
      cond do
        !params["prev_page_number"] -> 1
        params["next_page"] -> String.to_integer(params["prev_page_number"]) + 1
        params["prev_page"] -> String.to_integer(params["prev_page_number"]) - 1
      end

    next_page_path =
      case next_page_params(next_page, addresses_page, params) do
        nil ->
          nil

        next_page_params ->
          next_params =
            next_page_params
            |> Map.put("prev_page_path", cur_page_path(conn, params))
            |> Map.put("next_page", true)
            |> Map.put("prev_page_number", cur_page_number)

          address_path(
            conn,
            :index,
            next_params
          )
      end

    render(conn, "index.html",
      address_tx_count_pairs: addresses_page,
      page_address_count: Enum.count(addresses_page),
      address_count: Chain.count_addresses_with_balance_from_cache(),
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
      total_supply: Chain.total_supply(),
      next_page_path: next_page_path,
      prev_page_path: params["prev_page_path"],
      cur_page_number: cur_page_number
    )
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.total_transactions_sent_by_address(address)
  end

  def validation_count(%Address{} = address) do
    Chain.address_to_validation_count(address)
  end

  defp cur_page_path(conn, %{"hash" => _hash, "fetched_coin_balance" => _balance} = params) do
    new_params = Map.put(params, "next_page", false)

    address_path(
      conn,
      :index,
      new_params
    )
  end

  defp cur_page_path(conn, _), do: address_path(conn, :index)
end
