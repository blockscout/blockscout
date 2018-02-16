defmodule Explorer.Debit do
  @moduledoc """
    A materialized view representing the debits from an address.
  """

  use Ecto.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Address
  alias Explorer.Repo

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @primary_key false
  schema "debits" do
    belongs_to :address, Address, primary_key: true
    field :value, :decimal
    field :count, :integer
    timestamps()
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY debits;", [], timeout: 120_000)
  end
  def null, do: %__MODULE__{value: Decimal.new(0), count: 0}
end
