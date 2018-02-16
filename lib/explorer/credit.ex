defmodule Explorer.Credit do
  @moduledoc """
    A materialized view representing the credits to an address.
  """

  use Ecto.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Address
  alias Explorer.Repo

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @primary_key false
  schema "credits" do
    belongs_to :address, Address, primary_key: true
    field :value, :decimal
    field :count, :integer
    timestamps()
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY credits;", [])
  end
end
