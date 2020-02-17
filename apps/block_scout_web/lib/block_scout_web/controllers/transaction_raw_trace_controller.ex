defmodule BlockScoutWeb.TransactionRawTraceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.TransactionView
  alias EthereumJSONRPC
  alias EthereumJSONRPC.Parity
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.InternalTransaction

  def index(conn, %{"transaction_id" => hash_string}) do
    with {:ok, hash} <- Chain.string_to_transaction_hash(hash_string),
         {:ok, transaction} <-
           Chain.hash_to_transaction(
             hash,
             necessity_by_association: %{
               :block => :optional,
               [created_contract_address: :names] => :optional,
               [from_address: :names] => :optional,
               [to_address: :names] => :optional,
               [to_address: :smart_contract] => :optional,
               :token_transfers => :optional
             }
           ) do
      internal_transactions = Chain.all_transaction_to_internal_transactions(hash)
      IO.inspect("Gimme internal transactions:")
      IO.inspect(internal_transactions)

      first_trace_exists =
        Enum.find_index(internal_transactions, fn trace ->
          IO.inspect("Gimme trace.index:")
          IO.inspect(trace.index)
          trace.index == 0
        end)

      IO.inspect("Gimme first_trace_exists")
      IO.inspect(first_trace_exists)

      if first_trace_exists do
        IO.inspect("Gimme: index exists!!!")
      end

      internal_transactions =
        unless first_trace_exists do
          IO.inspect("Gimme: No first trace found")

          {:ok, first_trace_params} =
            Parity.fetch_first_trace(
              [%{block_number: transaction.block_number, hash_data: hash_string, transaction_index: transaction.index}],
              Application.get_env(:explorer, :json_rpc_named_arguments)
            )

          InternalTransaction.import_first_trace(first_trace_params)
          Chain.all_transaction_to_internal_transactions(hash)
        else
          internal_transactions
        end

      IO.inspect("Gimme internal transactions to raw trace 1:")
      IO.inspect(internal_transactions)

      render(
        conn,
        "index.html",
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        internal_transactions: internal_transactions,
        block_height: Chain.block_height(),
        show_token_transfers: Chain.transaction_has_token_transfers?(hash),
        transaction: transaction
      )
    else
      :error ->
        conn
        |> put_status(422)
        |> put_view(TransactionView)
        |> render("invalid.html", transaction_hash: hash_string)

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> put_view(TransactionView)
        |> render("not_found.html", transaction_hash: hash_string)
    end
  end
end
