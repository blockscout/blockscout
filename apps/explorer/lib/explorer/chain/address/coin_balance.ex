defmodule Explorer.Chain.Address.CoinBalance do
  @moduledoc """
  The `t:Explorer.Chain.Wei.t/0` `value` of `t:Explorer.Chain.Address.t/0` at the end of a `t:Explorer.Chain.Block.t/0`
  `t:Explorer.Chain.Block.block_number/0`.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @optional_fields ~w(value value_fetched_at)a
  @required_fields ~w(address_hash block_number)a
  @allowed_fields @optional_fields ++ @required_fields

  @typedoc """
   * `address` - the `t:Explorer.Chain.Address.t/0` with `value` at end of `block_number`.
   * `address_hash` - foreign key for `address`.
   * `block_number` - the `t:Explorer.Chain.Block.block_number/0` for the `t:Explorer.Chain.Block.t/0` at the end of
       which `address` had `value`.  When `block_number` is the greatest `t:Explorer.Chain.Block.block_number/0` for a
       given `address`, the `t:Explorer.Chain.Address.t/0` `fetched_balance_block_number` will match this value.
   * `inserted_at` - When the balance was first inserted into the database.
   * `updated_at` - When the balance was last updated.
   * `value` - the value of `address` at the end of the `t:Explorer.Chain.Block.block_number/0` for the
       `t:Explorer.Chain.Block.t/0`.  When `block_number` is the greatest `t:Explorer.Chain.Block.block_number/0` for a
       given `address`, the `t:Explorer.Chain.Address.t/0` `fetched_balance` will match this value.
   * `value_fetched_at` - when `value` was fetched.
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          block_number: Block.block_number(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          value: Wei.t() | nil
        }

  @primary_key false
  schema "address_coin_balances" do
    field(:block_number, :integer)
    field(:value, Wei)
    field(:value_fetched_at, :utc_datetime)

    timestamps()

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
  end

  def changeset(%__MODULE__{} = balance, params) do
    balance
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> unique_constraint(:block_number, name: :address_coin_balances_address_hash_block_number_index)
  end
end
