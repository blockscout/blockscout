defmodule BlockScoutWeb.InternalTransactionView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.{Address, InternalTransaction}

  def create?(%InternalTransaction{type: :create}), do: true
  def create?(_), do: false

  # This is the address to be shown in the to field
  def to_address_hash(%InternalTransaction{to_address_hash: nil, created_contract_address_hash: hash}), do: hash

  def to_address_hash(%InternalTransaction{to_address_hash: hash}), do: hash

  def to_address(%InternalTransaction{to_address: nil, created_contract_address: %Address{} = address}), do: address
  def to_address(%InternalTransaction{to_address: %Address{} = address}), do: address
end
