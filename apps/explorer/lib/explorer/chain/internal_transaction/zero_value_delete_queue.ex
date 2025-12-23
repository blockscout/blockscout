defmodule Explorer.Chain.InternalTransaction.ZeroValueDeleteQueue do
  @moduledoc """
  Stores numbers for blocks, whose zero-value internal transactions should be deleted
  """

  use Explorer.Schema

  @primary_key false
  typed_schema "internal_transactions_zero_value_delete_queue" do
    field(:block_number, :integer, primary_key: true)

    timestamps()
  end
end
