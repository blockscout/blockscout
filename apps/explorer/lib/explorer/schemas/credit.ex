defmodule Explorer.Credit do
  @moduledoc """
    A materialized view representing the credits to an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Address
  alias Explorer.Repo

  @primary_key false
  schema "credits" do
    belongs_to(:address, Address, primary_key: true)
    field(:value, :decimal)
    field(:count, :integer)
    timestamps()
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY credits;", [], timeout: 120_000)
  end

  def null, do: %__MODULE__{value: Decimal.new(0), count: 0}
end
