defmodule Explorer.Chain.Address.TokenBalance do
  @moduledoc """
  Represents a token balance from an address.

  In this table we can see all token balances that a specific addresses had according to the block
  numbers. If you want to show only the last balance from an address, consider querying against
  `Address.CurrentTokenBalance` instead.
  """

  use Explorer.Schema

  alias Explorer.Chain
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.{Address, Block, Hash, Token}

  @typedoc """
   *  `address` - The `t:Explorer.Chain.Address.t/0` that is the balance's owner.
   *  `address_hash` - The address hash foreign key.
   *  `token` - The `t:Explorer.Chain.Token/0` so that the address has the balance.
   *  `token_contract_address_hash` - The contract address hash foreign key.
   *  `block_number` - The block's number that the transfer took place.
   *  `value` - The value that's represents the balance.
   *  `token_id` - The token_id of the transferred token (applicable for ERC-1155 and ERC-721 tokens)
   *  `token_type` - The type of the token
  """
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          token: %Ecto.Association.NotLoaded{} | Token.t(),
          token_contract_address_hash: Hash.Address,
          block_number: Block.block_number(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          value: Decimal.t() | nil,
          token_id: non_neg_integer() | nil,
          token_type: String.t()
        }

  schema "address_token_balances" do
    field(:value, :decimal)
    field(:block_number, :integer)
    field(:value_fetched_at, :utc_datetime_usec)
    field(:token_id, :decimal)
    field(:token_type, :string)

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

  @optional_fields ~w(value value_fetched_at token_id)a
  @required_fields ~w(address_hash block_number token_contract_address_hash token_type)a
  @allowed_fields @optional_fields ++ @required_fields

  @doc false
  def changeset(%TokenBalance{} = token_balance, attrs) do
    token_balance
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:token_contract_address_hash)
    |> unique_constraint(:block_number, name: :token_balances_address_hash_block_number_index)
  end

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @doc """
  Builds an `Ecto.Query` to fetch the unfetched token balances.

  Unfetched token balances are the ones that have the column `value_fetched_at` nil or the value is null. This query also
  ignores the burn_address for tokens ERC-721 since the most tokens ERC-721 don't allow get the
  balance for burn_address.
  """
  def unfetched_token_balances do
    from(
      tb in TokenBalance,
      join: t in Token,
      on: tb.token_contract_address_hash == t.contract_address_hash,
      where:
        ((tb.address_hash != ^@burn_address_hash and t.type == "ERC-721") or t.type == "ERC-20" or t.type == "ERC-1155") and
          (is_nil(tb.value_fetched_at) or is_nil(tb.value))
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch the token balance of the given token contract hash of the given address in the given block.
  """
  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, token_id \\ nil)

  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, nil) do
    from(
      tb in TokenBalance,
      where: tb.address_hash == ^address_hash,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.block_number <= ^block_number,
      limit: ^1,
      order_by: [desc: :block_number]
    )
  end

  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, token_id) do
    from(
      tb in TokenBalance,
      where: tb.address_hash == ^address_hash,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.token_id == ^token_id,
      where: tb.block_number <= ^block_number,
      limit: ^1,
      order_by: [desc: :block_number]
    )
  end
end
