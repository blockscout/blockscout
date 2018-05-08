defmodule Explorer.Chain.Debit do
  @moduledoc """
    A materialized view representing the debits from an address.
  """

  use Explorer.Schema

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.{Address, Hash, Wei}
  alias Explorer.Repo

  @typedoc """
  * `address` - address that was the `from_address`
  * `address_hash` - foreign key for `address`
  * `count` - the number of debits to `address`
  * `value` - sum of all debit values.
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Truncated.t(),
          count: non_neg_integer,
          value: Decimal.t()
        }

  @primary_key false
  schema "debits" do
    field(:count, :integer)
    field(:value, Wei)

    timestamps()

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Truncated)
  end

  def refresh do
    SQL.query!(Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY debits;", [], timeout: 120_000)
  end
end
