defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Transaction}

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

  def transaction_from_or_to_current_address?(%Transaction{} = transaction, address_hash) do
    transaction.from_address_hash == address_hash || transaction.to_address_hash == address_hash
  end
end
