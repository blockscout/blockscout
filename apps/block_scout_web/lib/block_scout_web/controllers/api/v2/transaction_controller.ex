defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @necessity_by_association %{
    :block => :optional,
    :to_address => :optional,
    [created_contract_address: :names] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    [to_address: :smart_contract] => :optional
  }

  @token_transfers_neccessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    from_address: :required,
    to_address: :required,
    token: :required
  }

  def transaction(conn, %{"transaction_hash" => transaction_hash_string}) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_transaction_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found,
            Chain.hash_to_transaction(
              transaction_hash,
              necessity_by_association: @necessity_by_association
            )},
         preloaded <- Chain.preload_token_transfers(transaction, @token_transfers_neccessity_by_association) do
      conn
      |> put_status(200)
      |> render(:transaction, %{transaction: preloaded})
    end
  end
end
