defmodule BlockScoutWeb.API.V2.InternalTransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.{Block, InternalTransaction, Wei}

  def render("internal_transaction.json", %{internal_transaction: nil}) do
    nil
  end

  def render("internal_transaction.json", %{
        internal_transaction: internal_transaction,
        block: block
      }) do
    prepare_internal_transaction(internal_transaction, block)
  end

  def render("internal_transactions.json", %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(internal_transactions, &prepare_internal_transaction(&1, &1.block)),
      "next_page_params" => next_page_params
    }
  end

  @doc """
    Prepares internal transaction object to be returned in the API v2 endpoints.
  """
  @spec prepare_internal_transaction(InternalTransaction.t(), Block.t() | nil) :: map()
  def prepare_internal_transaction(internal_transaction, block \\ nil) do
    %{
      "error" => internal_transaction.error,
      "success" => is_nil(internal_transaction.error),
      "type" => InternalTransaction.call_type(internal_transaction) || internal_transaction.type,
      "transaction_hash" => internal_transaction.transaction_hash,
      "transaction_index" => internal_transaction.transaction_index,
      "from" =>
        Helper.address_with_info(nil, internal_transaction.from_address, internal_transaction.from_address_hash, false),
      "to" =>
        Helper.address_with_info(nil, internal_transaction.to_address, internal_transaction.to_address_hash, false),
      "created_contract" =>
        Helper.address_with_info(
          nil,
          internal_transaction.created_contract_address,
          internal_transaction.created_contract_address_hash,
          false
        ),
      "value" => internal_transaction.value || Wei.zero(),
      "block_number" => internal_transaction.block_number,
      "timestamp" => (block && block.timestamp) || (internal_transaction.block && internal_transaction.block.timestamp),
      "index" => internal_transaction.index,
      "gas_limit" => internal_transaction.gas || Decimal.new(0),
      "block_index" => internal_transaction.block_index
    }
  end
end
