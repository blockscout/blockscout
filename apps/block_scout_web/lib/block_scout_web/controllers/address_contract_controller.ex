# credo:disable-for-this-file
defmodule BlockScoutWeb.AddressContractController do
  use BlockScoutWeb, :controller

  require Logger

  #  import BlockScoutWeb.AddressController, only: [transaction_and_validation_count: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string}) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :celo_account => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      Logger.debug("Address Found #{address_hash}")
      Logger.debug("Smart Contract #{address}")

      with {:ok, implementation_address} <- Chain.get_proxied_address(address_hash),
           {:ok, implementation_contract} <- Chain.find_contract_address(implementation_address, address_options, true) do
        Logger.debug("Implementation address FOUND in proxy table #{implementation_address}")

        render(
          conn,
          "index.html",
          address: implementation_contract,
          proxy: address,
          is_proxy: true,
          coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string})
        )
      else
        {:error, :not_found} ->
          Logger.debug("Implementation address NOT found in proxy table")

          render(
            conn,
            "index.html",
            address: address,
            proxy: nil,
            is_proxy: false,
            coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            counters_path: nil
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
