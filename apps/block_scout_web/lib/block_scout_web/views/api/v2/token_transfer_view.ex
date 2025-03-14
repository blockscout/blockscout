defmodule BlockScoutWeb.API.V2.TokenTransferView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenView, TransactionView}
  alias BlockScoutWeb.Tokens.Helper, as: TokensHelper
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.{TokenTransfer, Transaction}

  def render("token_transfer.json", %{token_transfer: nil}) do
    nil
  end

  def render("token_transfer.json", %{
        token_transfer: token_transfer,
        decoded_transaction_input: decoded_transaction_input,
        conn: conn
      }) do
    prepare_token_transfer(token_transfer, conn, decoded_transaction_input)
  end

  def render("token_transfers.json", %{
        token_transfers: token_transfers,
        decoded_transactions_map: decoded_transactions_map,
        next_page_params: next_page_params,
        conn: conn
      }) do
    %{
      "items" =>
        Enum.map(
          token_transfers,
          &render("token_transfer.json", %{
            token_transfer: &1,
            decoded_transaction_input: &1.transaction && decoded_transactions_map[&1.transaction.hash],
            conn: conn
          })
        ),
      "next_page_params" => next_page_params
    }
  end

  @doc """
    Prepares token transfer object to be returned in the API v2 endpoints.
  """
  @spec prepare_token_transfer(TokenTransfer.t(), Plug.Conn.t() | nil, any()) :: map()
  def prepare_token_transfer(token_transfer, _conn, decoded_input) do
    %{
      "transaction_hash" => token_transfer.transaction_hash,
      "from" => Helper.address_with_info(nil, token_transfer.from_address, token_transfer.from_address_hash, false),
      "to" => Helper.address_with_info(nil, token_transfer.to_address, token_transfer.to_address_hash, false),
      "total" => prepare_token_transfer_total(token_transfer),
      "token" => TokenView.render("token.json", %{token: token_transfer.token}),
      "type" => Chain.get_token_transfer_type(token_transfer),
      "timestamp" =>
        if(match?(%NotLoaded{}, token_transfer.block),
          do: TransactionView.block_timestamp(token_transfer.transaction),
          else: TransactionView.block_timestamp(token_transfer.block)
        ),
      "method" => Transaction.method_name(token_transfer.transaction, decoded_input, true),
      "block_hash" => to_string(token_transfer.block_hash),
      "block_number" => token_transfer.block_number,
      "log_index" => token_transfer.log_index
    }
  end

  @doc """
    Prepares token transfer total value/id transferred to be returned in the API v2 endpoints.
  """
  @spec prepare_token_transfer_total(TokenTransfer.t()) :: map()
  # credo:disable-for-next-line /Complexity/
  def prepare_token_transfer_total(token_transfer) do
    case TokensHelper.token_transfer_amount_for_api(token_transfer) do
      {:ok, :erc721_instance} ->
        %{
          "token_id" => token_transfer.token_ids && List.first(token_transfer.token_ids),
          "token_instance" =>
            token_transfer.token_instance &&
              TokenView.prepare_token_instance(token_transfer.token_instance, token_transfer.token)
        }

      {:ok, :erc1155_erc404_instance, value, decimals} ->
        %{
          "token_id" => token_transfer.token_ids && List.first(token_transfer.token_ids),
          "value" => value,
          "decimals" => decimals,
          "token_instance" =>
            token_transfer.token_instance &&
              TokenView.prepare_token_instance(token_transfer.token_instance, token_transfer.token)
        }

      {:ok, :erc1155_erc404_instance, values, token_ids, decimals} ->
        %{
          "token_id" => token_ids && List.first(token_ids),
          "value" => values && List.first(values),
          "decimals" => decimals,
          "token_instance" =>
            token_transfer.token_instance &&
              TokenView.prepare_token_instance(token_transfer.token_instance, token_transfer.token)
        }

      {:ok, value, decimals} ->
        %{"value" => value, "decimals" => decimals}

      _ ->
        nil
    end
  end
end
