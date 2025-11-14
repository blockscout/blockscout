defmodule Explorer.Utility.InternalTransactionsAddressPlaceholder do
  @moduledoc """
  Module is responsible for keeping the information about the presence of internal transactions
  on a particular address inside specific block
  """

  use Explorer.Schema

  @primary_key false
  typed_schema "deleted_internal_transactions_address_placeholders" do
    field(:address_id, :integer, primary_key: true)
    field(:block_number, :integer, primary_key: true)
    field(:count_tos, :integer)
    field(:count_froms, :integer)
  end

  @doc false
  def changeset(placeholder \\ %__MODULE__{}, params) do
    cast(placeholder, params, [:address_id, :block_number, :count_tos, :count_froms])
  end
end
