defmodule Explorer.Chain.Address.CurrentTokenBalance do
  @moduledoc """
  Represents the current token balance from addresses according to the last block.

  In this table we can see only the last balance from addresses. If you want to see the history of
  token balances look at the `Address.TokenBalance` instead.
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, limit: 2, offset: 2, order_by: 3, preload: 2, subquery: 1, where: 3]

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, BridgedToken, Hash, Token}

  @default_paging_options %PagingOptions{page_size: 50}

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
          max_block_number: Block.block_number(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          value: Decimal.t() | nil,
          token_id: non_neg_integer() | nil,
          token_type: String.t()
        }

  schema "address_current_token_balances" do
    field(:value, :decimal)
    field(:block_number, :integer)
    field(:max_block_number, :integer, virtual: true)
    field(:value_fetched_at, :utc_datetime_usec)
    field(:token_id, :decimal)
    field(:token_type, :string)

    # A transient field for deriving token holder count deltas during address_current_token_balances upserts
    field(:old_value, :decimal)

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
  def changeset(%__MODULE__{} = token_balance, attrs) do
    token_balance
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> foreign_key_constraint(:token_contract_address_hash)
  end

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @doc """
  Builds an `Ecto.Query` to fetch the token holders from the given token contract address hash.

  The Token Holders are the addresses that own a positive amount of the Token. So this query is
  considering the following conditions:

  * The token balance from the last block.
  * Balances greater than 0.
  * Excluding the burn address (0x0000000000000000000000000000000000000000).

  """
  def token_holders_ordered_by_value(token_contract_address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    token_contract_address_hash
    |> token_holders_query
    |> preload(:address)
    |> order_by([tb], desc: :value, desc: :address_hash)
    |> page_token_balances(paging_options)
    |> limit(^paging_options.page_size)
    |> offset(^offset)
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current token balances of the given address.
  """
  def last_token_balances(address_hash) do
    from(
      ctb in __MODULE__,
      where: ctb.address_hash == ^address_hash,
      where: ctb.value > 0,
      left_join: bt in BridgedToken,
      on: ctb.token_contract_address_hash == bt.home_token_contract_address_hash,
      preload: :token,
      select: {ctb, bt}
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current balance of the given address for the given token.
  """
  def last_token_balance(address_hash, token_contract_address_hash) do
    from(
      tb in __MODULE__,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.address_hash == ^address_hash,
      select: tb.value
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch addresses that hold the token.

  Token holders cannot be the burn address (#{@burn_address_hash}) and must have a non-zero value.
  """
  def token_holders_query(token_contract_address_hash) do
    with token <- Repo.get_by(Token, contract_address_hash: token_contract_address_hash),
         "ERC-20" <- token.type do
      from(
        tb in __MODULE__,
        where: tb.token_contract_address_hash == ^token_contract_address_hash,
        where: tb.address_hash != ^@burn_address_hash,
        where: tb.value > 0
      )
    else
      _ ->
        query =
          from(
            tb in __MODULE__,
            where: tb.token_contract_address_hash == ^token_contract_address_hash,
            where: tb.address_hash != ^@burn_address_hash,
            where: tb.value > 0,
            windows: [
              w: [partition_by: [tb.token_contract_address_hash, tb.address_hash]]
            ],
            select: %__MODULE__{
              token_contract_address_hash: tb.token_contract_address_hash,
              address_hash: tb.address_hash,
              value: tb.value,
              block_number: tb.block_number,
              max_block_number: over(max(tb.block_number), :w)
            }
          )

        from(
          q in subquery(query),
          where: q.max_block_number == q.block_number,
          select: q,
          distinct: q.address_hash
        )
    end
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
