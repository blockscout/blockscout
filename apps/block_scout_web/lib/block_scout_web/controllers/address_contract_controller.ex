defmodule BlockScoutWeb.AddressContractController do
  use BlockScoutWeb, :controller

  require Logger

  import BlockScoutWeb.AddressController, only: [transaction_and_validation_count: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

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

      with {:ok, proxy_contract} <- Chain.get_proxied_address(address_hash),
           {:ok, proxied_address} <- Chain.find_contract_address(proxy_contract, address_options, true) do
        Logger.debug("Implementation address FOUND in proxy table #{proxy_contract}")
        render(
          conn,
          "index.html",
          address: proxied_address,
          proxy: address,
          is_proxy: true,
          coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          transaction_count: transaction_count,
          validation_count: validation_count
        )
      else
        {:error, :not_found} ->
          Logger.debug("Implementation address NOT found in proxy table")
        render(
          conn,
          "index.html",
          address: address,
          proxied_address: nil,
          is_proxy: false,
          coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          transaction_count: transaction_count,
          validation_count: validation_count
        )
      end

    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
