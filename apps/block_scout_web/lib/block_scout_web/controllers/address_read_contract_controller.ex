# credo:disable-for-this-file
#
# When moving the calls to ajax, this controller became very similar to the
# `address_contract_controller`, but both are necessary until we are able to
# address a better way to organize the controllers.
#
# So, for now, I'm adding this comment to disable the credo check for this file.
defmodule BlockScoutWeb.AddressReadContractController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

  import BlockScoutWeb.AddressController, only: [transaction_and_validation_count: 1]

  def index(conn, %{"address_id" => address_hash_string}) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      {transaction_count, validation_count} = transaction_and_validation_count(address_hash)

      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        transaction_count: transaction_count,
        validation_count: validation_count
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
