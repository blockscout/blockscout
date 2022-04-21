# credo:disable-for-this-file
defmodule BlockScoutWeb.AddressWriteProxyController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.Account.AuthController
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
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
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true),
         false <- is_nil(address.smart_contract),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      current_user = AuthController.current_user(conn)
      tags = GetAddressTags.call(address_hash, current_user)

      render(
        conn,
        "index.html",
        address: address,
        type: :proxy,
        action: :write,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        tags: tags
      )
    else
      _ ->
        not_found(conn)
    end
  end
end
