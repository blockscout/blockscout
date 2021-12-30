defmodule BlockScoutWeb.AddressRewardController do
    use BlockScoutWeb, :controller

    import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  
    alias BlockScoutWeb.{AccessHelpers, Controller, TransactionView}
    alias Explorer.{Chain, Market}
  
    alias Explorer.Chain.{
      AddressInternalTransactionCsvExporter,
      AddressLogCsvExporter,
      AddressTokenTransferCsvExporter,
      AddressTransactionCsvExporter
    }
  
    alias Explorer.ExchangeRates.Token
    alias Indexer.Fetcher.CoinBalanceOnDemand
    alias Phoenix.View
  
    @transaction_necessity_by_association [
      necessity_by_association: %{
        [created_contract_address: :names] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional,
        :block => :optional
      }
    ]
  
    {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
    @burn_address_hash burn_address_hash

    def index(conn, %{"address_id" => address_hash_string} = params) do
        with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
             {:ok, address} <- Chain.hash_to_address(address_hash),
             {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
          render(
            conn,
            "index.html",
            address: address,
            coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            filter: params["filter"],
            counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
            current_path: Controller.current_full_path(conn)
          )
        else
          :error ->
            unprocessable_entity(conn)
    
          {:restricted_access, _} ->
            not_found(conn)
    
          {:error, :not_found} ->
            {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
            address = %Chain.Address{hash: address_hash, smart_contract: nil, token: nil}
    
            case Chain.Hash.Address.validate(address_hash_string) do
              {:ok, _} ->
                render(
                  conn,
                  "index.html",
                  address: address,
                  coin_balance_status: nil,
                  exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
                  filter: params["filter"],
                  counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
                  current_path: Controller.current_full_path(conn)
                )
    
              _ ->
                not_found(conn)
            end
        end
      end
end