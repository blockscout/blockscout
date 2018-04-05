defmodule Explorer.Chain.Debit do
  @moduledoc """
    A materialized view representing the debits from an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.Address
  alias Explorer.Repo

  @primary_key false
  schema "debits" do
    field(:count, :integer)
    field(:value, :decimal)

    timestamps()

    belongs_to(:address, Address, primary_key: true)
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY debits;", [], timeout: 120_000)
  end

  def null, do: %__MODULE__{value: Decimal.new(0), count: 0}
end
