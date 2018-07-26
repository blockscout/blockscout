defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  import ExplorerWeb.AddressView,
    only: [contract?: 1, smart_contract_verified?: 1, smart_contract_with_read_only_functions?: 1]

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end

  @doc """
  Check if the given address is the to_address_hash or from_address_hash from the transaction.

  When the transaction has token transfers, the transaction is going to be shown even when the 
  transaction is the to or from of the given address.
  """
  def transaction_from_or_to_current_address?(transaction, address_hash) do
    transaction.from_address_hash == address_hash || transaction.to_address_hash == address_hash
  end

  @doc """
  Formats the given amount according to given decimals.

  ## Examples

  iex> ExplorerWeb.AddressTransactionView.formatted_token_amount(Decimal.new(20500000), 5)
  "205"

  iex> ExplorerWeb.AddressTransactionView.formatted_token_amount(Decimal.new(20500000), 7)
  "2.05"

  iex> ExplorerWeb.AddressTransactionView.formatted_token_amount(Decimal.new(205000), 12)
  "0.000000205"

  """
  @spec formatted_token_amount(Decimal.t(), non_neg_integer()) :: String.t()
  def formatted_token_amount(%Decimal{sign: sign, coef: coef, exp: exp}, decimals) do
    sign
    |> Decimal.new(coef, exp - decimals)
    |> Decimal.reduce()
    |> Decimal.to_string(:normal)
  end
end
