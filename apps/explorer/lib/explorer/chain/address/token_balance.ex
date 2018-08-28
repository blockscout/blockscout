defmodule Explorer.Chain.Address.TokenBalance do
  @moduledoc """
  Represents a token balance from an address.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.{Address, Block, Hash, Token}

  @typedoc """
   *  `address` - The `t:Explorer.Chain.Address.t/0` that is the balance's owner.
   *  `address_hash` - The address hash foreign key.
   *  `token` - The `t:Explorer.Chain.Token/0` so that the address has the balance.
   *  `token_contract_address_hash` - The contract address hash foreign key.
   *  `block_number` - The block's number that the transfer took place.
   *  `value` - The value that's represents the balance.
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          token: %Ecto.Association.NotLoaded{} | Token.t(),
          token_contract_address_hash: Hash.Address,
          block_number: Block.block_number(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          value: Decimal.t() | nil
        }

  schema "address_token_balances" do
    field(:value, :decimal)
    field(:block_number, :integer)
    field(:value_fetched_at, :utc_datetime)

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      type: Hash.Address
    )

    timestamps()
  end

  @optional_fields ~w(value value_fetched_at)a
  @required_fields ~w(address_hash block_number token_contract_address_hash)a
  @allowed_fields @optional_fields ++ @required_fields

  @doc false
  def changeset(%TokenBalance{} = token_balance, attrs) do
    token_balance
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> foreign_key_constraint(:token_contract_address_hash)
    |> unique_constraint(:block_number, name: :token_balances_address_hash_block_number_index)
  end

  @doc """
  Builds an `Ecto.Query` to fetch the last token balances.

  The last token balances from an Address is the last block indexed.
  """
  def last_token_balances(address_hash) do
    from(
      tb in TokenBalance,
      where: tb.address_hash == ^address_hash and tb.value > 0,
      distinct: :token_contract_address_hash,
      order_by: [desc: :block_number],
      preload: :token
    )
  end
end
