defmodule ExplorerWeb.InternalTransactionView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.InternalTransaction

  def create?(%InternalTransaction{type: :create}), do: true
  def create?(_), do: false

  # This is the address to be shown in the to field
  def display_to_address(%InternalTransaction{to_address_hash: nil, created_contract_address_hash: address_hash}),
    do: [address: nil, address_hash: address_hash]

  def display_to_address(%InternalTransaction{to_address: address}), do: [address: address]
end
