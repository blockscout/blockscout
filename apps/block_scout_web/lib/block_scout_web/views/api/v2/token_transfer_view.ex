defmodule BlockScoutWeb.API.V2.TokenTransferView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenView}
  alias Explorer.Chain.Transaction

  def render("token_transfer.json", %{token_transfer: nil}) do
    nil
  end

  def render("token_transfer.json", %{
        token_transfer: token_transfer,
        decoded_transaction_input: decoded_transaction_input
      }) do
    %{
      "transaction_hash" => token_transfer.transaction_hash,
      "block_number" => token_transfer.block_number,
      "log_index" => token_transfer.log_index,
      "block_timestamp" => token_transfer.transaction.block_timestamp,
      "amounts_or_token_ids" => token_transfer.amounts || [token_transfer.amount || 1],
      "from" => Helper.address_with_info(nil, token_transfer.from_address, token_transfer.from_address_hash, false),
      "to" => Helper.address_with_info(nil, token_transfer.to_address, token_transfer.to_address_hash, false),
      "token" =>
        TokenView.render("token.json", %{
          token: token_transfer.token,
          contract_address_hash: Transaction.bytes_to_address_hash(token_transfer.token_contract_address_hash)
        }),
      "method" => Transaction.method_name(token_transfer.transaction, decoded_transaction_input, true)
    }
  end

  def render("token_transfers.json", %{
        token_transfers: token_transfers,
        decoded_transactions_map: decoded_transactions_map,
        next_page_params: next_page_params
      }) do
    %{
      "items" =>
        Enum.map(
          token_transfers,
          &render("token_transfer.json", %{
            token_transfer: &1,
            decoded_transaction_input: decoded_transactions_map[&1.transaction.hash]
          })
        ),
      "next_page_params" => next_page_params
    }
  end
end
