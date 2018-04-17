defmodule Explorer.Chain.Credit do
  @moduledoc """
    A materialized view representing the credits to an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.Address
  alias Explorer.Repo

  @primary_key false
  schema "credits" do
    field(:count, :integer)
    field(:value, :decimal)

    timestamps()

    belongs_to(:address, Address, primary_key: true)
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY credits;", [], timeout: 120_000)
  end
end
