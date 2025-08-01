defmodule BlockScoutWeb.TransactionRawTraceController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]
  import BlockScoutWeb.Models.GetTransactionTags, only: [get_transaction_with_addresses_tags: 2]

  alias BlockScoutWeb.{AccessHelper, TransactionController}
  alias EthereumJSONRPC
  alias Explorer.{Chain, Market}
  alias Indexer.Fetcher.OnDemand.FirstTrace, as: FirstTraceOnDemand

  def index(conn, %{"transaction_id" => hash_string} = params) do
    with {:ok, hash} <- Chain.string_to_full_hash(hash_string),
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
           ),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      if is_nil(transaction.block_number) do
        render_raw_trace(conn, [], transaction, hash)
      else
        FirstTraceOnDemand.maybe_trigger_fetch(transaction)

        case Chain.fetch_transaction_raw_traces(transaction) do
          {:ok, raw_traces} -> render_raw_trace(conn, raw_traces, transaction, hash)
          _error -> unprocessable_entity(conn)
        end
      end
    else
      {:restricted_access, _} ->
        TransactionController.set_not_found_view(conn, hash_string)

      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        TransactionController.set_not_found_view(conn, hash_string)
    end
  end

  defp render_raw_trace(conn, raw_traces, transaction, hash) do
    render(
      conn,
      "index.html",
      exchange_rate: Market.get_coin_exchange_rate(),
      raw_traces: raw_traces,
      block_height: Chain.block_height(),
      current_user: current_user(conn),
      show_token_transfers: Chain.transaction_has_token_transfers?(hash),
      transaction: transaction,
      from_tags: get_address_tags(transaction.from_address_hash, current_user(conn)),
      to_tags: get_address_tags(transaction.to_address_hash, current_user(conn)),
      transaction_tags:
        get_transaction_with_addresses_tags(
          transaction,
          current_user(conn)
        )
    )
  end
end
