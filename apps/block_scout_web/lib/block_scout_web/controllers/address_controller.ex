defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  def index(conn, _params) do
    address_count_module = Application.get_env(:block_scout_web, :fake_adapter) || Chain

    render(conn, "index.html",
      addresses: Chain.list_top_addresses(),
      address_estimated_count: address_count_module.address_estimated_count(),
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    )
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count_estimate(address)
  end
end
