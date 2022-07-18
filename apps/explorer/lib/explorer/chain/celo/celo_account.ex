defmodule Explorer.Chain.CeloAccount do
  @moduledoc """
  Datatype for storing Celo accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, CeloClaims, Hash, Wei}

  #    @type account_type :: %__MODULE__{ :regular | :validator | :group }

  @typedoc """
  * `address` - address of the account.
  * `account_type` - regular, validator or validator group
  * `locked_gold` - total locked gold
  * `nonvoting_locked_gold` - non-voting locked gold
  * `rewards` - rewards in CELO
  """

  @type t :: %__MODULE__{
          address: Hash.Address.t(),
          account_type: String.t(),
          locked_gold: Wei.t(),
          nonvoting_locked_gold: Wei.t(),
          usd: Wei.t(),
          attestations_requested: non_neg_integer(),
          attestations_fulfilled: non_neg_integer()
        }

  @attrs ~w(
        address name url account_type nonvoting_locked_gold locked_gold attestations_requested attestations_fulfilled usd
    )a

  @required_attrs ~w(
        address
    )a

  schema "celo_account" do
    field(:account_type, :string)
    field(:name, :string)
    field(:url, :string)
    field(:nonvoting_locked_gold, Wei)
    field(:locked_gold, Wei)
    field(:active_gold, Wei, virtual: true)
    field(:usd, Wei)

    field(:votes, Wei, virtual: true)

    field(:attestations_requested, :integer)
    field(:attestations_fulfilled, :integer)

    belongs_to(
      :account_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    has_many(:celo_claims, CeloClaims, foreign_key: :address)

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_account, attrs) do
    celo_account
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end
end
