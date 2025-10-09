# credo:disable-for-this-file
defmodule BlockScoutWeb.AddressReadProxyController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.AccessHelper
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
    ip = AccessHelper.conn_to_ip_string(conn)

    address_options = [
      necessity_by_association: %{
        :names => :optional,
        :smart_contract => :optional,
        :token => :optional,
        Address.contract_creation_transaction_associations() => :optional
      },
      ip: ip
    ]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options),
         false <- is_nil(address.smart_contract),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        type: :proxy,
        action: :read,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(ip, address),
        exchange_rate: Market.get_coin_exchange_rate(),
        counters_path: address_path(conn, :address_counters, %{"id" => Address.checksum(address_hash)}),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      _ ->
        not_found(conn)
    end
  end
end
