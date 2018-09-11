defmodule Explorer.Chain.Address.TokenBalance do
  @moduledoc """
  Represents a token balance from an address.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, limit: 2, where: 3, subquery: 1, order_by: 3, preload: 2]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.{Address, Block, Hash, Token}

  @default_paging_options %PagingOptions{page_size: 50}

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
  Builds an `Ecto.Query` to fetch the last token balances that have value greater than 0.

  The last token balances from an Address is the last block indexed.
  """
  def last_token_balances(address_hash) do
    query =
      from(
        tb in TokenBalance,
        where: tb.address_hash == ^address_hash,
        distinct: :token_contract_address_hash,
        order_by: [desc: :block_number]
      )

    from(tb in subquery(query), where: tb.value > 0, preload: :token)
  end

  @doc """
  Builds an `Ecto.Query` to fetch the token holders from the given token contract address hash.

  The Token Holders are the addresses that own a positive amount of the Token. So this query is
  considering the following conditions:

  * The token balance from the last block.
  * Balances greater than 0.
  * Excluding the burn address (0x0000000000000000000000000000000000000000).

  """
  def token_holders_from_token_hash(token_contract_address_hash) do
    query = token_holders_query(token_contract_address_hash)

    from(tb in subquery(query), where: tb.value > 0)
  end

  def token_holders_ordered_by_value(token_contract_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    token_contract_address_hash
    |> token_holders_from_token_hash()
    |> order_by([tb], desc: tb.value, desc: tb.address_hash)
    |> preload(:address)
    |> page_token_balances(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp token_holders_query(contract_address_hash) do
    {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

    from(
      tb in TokenBalance,
      distinct: :address_hash,
      where: tb.token_contract_address_hash == ^contract_address_hash and tb.address_hash != ^burn_address_hash,
      order_by: [desc: :block_number]
    )
  end

  defp page_token_balances(query, %PagingOptions{key: nil}), do: query

  defp page_token_balances(query, %PagingOptions{key: {value, address_hash}}) do
    where(
      query,
      [tb],
      tb.value < ^value or (tb.value == ^value and tb.address_hash < ^address_hash)
    )
  end
end
