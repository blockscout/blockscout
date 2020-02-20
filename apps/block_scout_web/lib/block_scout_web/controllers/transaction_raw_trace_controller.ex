defmodule BlockScoutWeb.TransactionRawTraceController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.TransactionView
  alias EthereumJSONRPC
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Runner.InternalTransactions
  alias Explorer.ExchangeRates.Token

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

      first_trace_exists =
        Enum.find_index(internal_transactions, fn trace ->
          trace.index == 0
        end)

      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      internal_transactions =
        if first_trace_exists do
          internal_transactions
        else
          {:ok, first_trace_params} =
            Chain.fetch_first_trace(
              [
                %{
                  block_hash: transaction.block_hash,
                  block_number: transaction.block_number,
                  hash_data: hash_string,
                  transaction_index: transaction.index
                }
              ],
              json_rpc_named_arguments
            )

          InternalTransactions.run_insert_only(first_trace_params, %{
            timeout: :infinity,
            timestamps: Import.timestamps(),
            internal_transactions: %{params: first_trace_params}
          })

          Chain.all_transaction_to_internal_transactions(hash)
        end

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
