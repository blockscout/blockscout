# credo:disable-for-this-file
defmodule BlockScoutWeb.AddressContractController do
  use BlockScoutWeb, :controller

  require Logger

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.AddressContractVerificationViaJsonController, as: VerificationController
  alias Explorer.{Chain, Market}
  alias Explorer.Etherscan.Contracts
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand

  def index(conn, %{"address_id" => address_hash_string} = params) do
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
         _ <- VerificationController.check_and_verify(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      Logger.debug("Address Found #{address_hash}")
      Logger.debug("Smart Contract #{address}")

      with {:ok, implementation_address} <- Contracts.get_proxied_address(address_hash),
           {:ok, implementation_contract} <- Chain.find_contract_address(implementation_address, address_options, true) do
        Logger.debug("Implementation address FOUND in proxy table #{implementation_address}")

        render(
          conn,
          "index.html",
          address: address,
          proxy: address,
          implementation: implementation_contract,
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
            counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string})
          )
      end
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
