defmodule BlockScoutWeb.AddressContractController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AddressController, only: [transaction_count: 1, validation_count: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  def index(conn, %{"address_id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash) do
      render(
        conn,
        "index.html",
        address: address,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        transaction_count: transaction_count(address),
        validation_count: validation_count(address)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
