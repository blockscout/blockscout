defmodule Explorer.Chain.Credit do
  @moduledoc """
    A materialized view representing the credits to an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @primary_key false
  schema "credits" do
    field(:count, :integer)
    field(:value, :decimal)

    timestamps()

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Truncated)
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY credits;", [], timeout: 120_000)
  end
end
