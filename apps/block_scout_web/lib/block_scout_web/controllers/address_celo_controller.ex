defmodule BlockScoutWeb.AddressCeloController do

    use BlockScoutWeb, :controller
    import BlockScoutWeb.AddressController, only: [transaction_and_validation_count: 1]
  
    alias Explorer.{Chain, Market}
    alias Explorer.ExchangeRates.Token
    alias Indexer.Fetcher.CoinBalanceOnDemand

    def index(conn, %{"address_id" => address_hash_string}) do
        with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
             {:ok, address} <- Chain.hash_to_address(address_hash) do
          IO.inspect(address)
          {transaction_count, validation_count} = transaction_and_validation_count(address_hash)
    
          render(
            conn,
            "index.html",
            address: address,
            current_path: current_path(conn),
            coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
            exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
            transaction_count: transaction_count,
            validation_count: validation_count
          )
        else
          _ ->
            not_found(conn)
        end
      end

end


