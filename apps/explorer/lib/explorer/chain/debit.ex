defmodule Explorer.Chain.Debit do
  @moduledoc """
    A materialized view representing the debits from an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Repo

  @primary_key false
  schema "debits" do
    field(:count, :integer)
    field(:value, Wei)

    timestamps()

    belongs_to(:address, Address, primary_key: true)
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY debits;", [], timeout: 120_000)
  end
end
