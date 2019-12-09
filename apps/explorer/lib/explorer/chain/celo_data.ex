defmodule Explorer.Chain.CeloData do
  @moduledoc """
  Stores data needed for Celo leaderboard
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  @typedoc """
  * `address` - address of the account.
  * `main_address` - main address that has claimed this account
  * ``
  """

  @type t :: %__MODULE__{
          claimed_address: Hash.Address.t(),
          address: Hash.Address.t(),
          gold: Wei.t(),
          usd: Wei.t(),
          locked_gold: Wei.t()
        }

  @attrs ~w(
          address main_address gold usd locked_gold
    )a

  @required_attrs ~w(
          address main_address
    )a

  schema "celo_data" do
    field(:gold, Wei)
    field(:locked_gold, Wei)
    field(:usd, Wei)

    belongs_to(
      :data_address,
      Address,
      foreign_key: :claimed_address,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :main_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_data, attrs) do
    celo_data
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end
end
