defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  def show(conn, %{"id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do

      render(
        conn,
        "show.html",
        address: address,
        transaction_count: transaction_count(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      )
    end
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count(address)
  end
end
