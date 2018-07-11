defmodule ExplorerWeb.InternalTransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.InternalTransaction

  def create?(%InternalTransaction{type: :create}), do: true
  def create?(_), do: false

  # This is the address to be shown in the to field
  def to_address_hash(%InternalTransaction{to_address_hash: nil, created_contract_address_hash: hash}), do: hash

  def to_address_hash(%InternalTransaction{to_address_hash: hash}), do: hash
end
