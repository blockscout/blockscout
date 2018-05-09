defmodule ExplorerWeb.ChainController do
  use ExplorerWeb, :controller

  alias Explorer.Chain.{Address, Block, Statistics, Transaction}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias ExplorerWeb.Chain

  def show(conn, _params) do
    render(
      conn,
      "show.html",
      chain: Statistics.fetch(),
      market_history_data: Market.fetch_recent_history(30),
      exchange_rate: Market.fetch_exchange_rate(coin()) || Token.null()
    )
  end

  def search(conn, %{"q" => query}) do
    query
    |> String.trim()
    |> Chain.from_param()
    |> case do
      {:ok, item} ->
        redirect_search_results(conn, item)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp coin do
    Application.get_env(:explorer, :coin)
  end

  defp redirect_search_results(conn, %Address{} = item) do
    redirect(conn, to: address_path(conn, :show, Gettext.get_locale(), item.hash))
  end

  defp redirect_search_results(conn, %Block{} = item) do
    redirect(conn, to: block_path(conn, :show, Gettext.get_locale(), item.number))
  end

  defp redirect_search_results(conn, %Transaction{} = item) do
    redirect(
      conn,
      to:
        transaction_path(
          conn,
          :show,
          Gettext.get_locale(),
          item.hash
        )
    )
  end
end
