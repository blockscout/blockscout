defmodule Explorer.Chain.Address.TokenBalance do
  @moduledoc """
  Represents a token balance from an address.

  In this table we can see all token balances that a specific addresses had according to the block
  numbers. If you want to show only the last balance from an address, consider querying against
  `Address.CurrentTokenBalance` instead.
  """

  use Explorer.Schema

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Block, Hash, Token}
  alias Explorer.Chain.Cache.BackgroundMigrations

  @typedoc """
   *  `address` - The `t:Explorer.Chain.Address.t/0` that is the balance's owner.
   *  `address_hash` - The address hash foreign key.
   *  `token` - The `t:Explorer.Chain.Token/0` so that the address has the balance.
   *  `token_contract_address_hash` - The contract address hash foreign key.
   *  `block_number` - The block's number that the transfer took place.
   *  `value` - The value that's represents the balance.
   *  `token_id` - The token_id of the transferred token (applicable for ERC-1155, ERC-721 and ERC-404 tokens)
   *  `token_type` - The type of the token
   *  `refetch_after` - when to refetch the token balance
   *  `retries_count` - number of times the token balance has been retried
  """
  typed_schema "address_token_balances" do
    field(:value, :decimal)
    field(:block_number, :integer) :: Block.block_number()
    field(:value_fetched_at, :utc_datetime_usec)
    field(:token_id, :decimal)
    field(:token_type, :string, null: false)
    field(:refetch_after, :utc_datetime_usec)
    field(:retries_count, :integer)

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address, null: false)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  @optional_fields ~w(value value_fetched_at token_id refetch_after retries_count)a
  @required_fields ~w(address_hash block_number token_contract_address_hash token_type)a
  @allowed_fields @optional_fields ++ @required_fields

  @doc false
  def changeset(%__MODULE__{} = token_balance, attrs) do
    token_balance
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:block_number, name: :token_balances_address_hash_block_number_index)
  end

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  @doc """
  Builds an `Ecto.Query` to fetch the unfetched token balances.

  Unfetched token balances are the ones that have the column `value_fetched_at` nil or the value is null. This query also
  ignores the burn_address for tokens ERC-721 since the most tokens ERC-721 don't allow get the
  balance for burn_address.
  """
  # credo:disable-for-next-line /Complexity/
  def unfetched_token_balances do
    if BackgroundMigrations.get_tb_token_type_finished() do
      from(
        tb in __MODULE__,
        where:
          ((tb.address_hash != ^@burn_address_hash and tb.token_type == "ERC-721") or tb.token_type == "ERC-20" or
             tb.token_type == "ZRC-2" or
             tb.token_type == "ERC-1155" or tb.token_type == "ERC-404") and
            (is_nil(tb.value_fetched_at) or is_nil(tb.value)) and
            (is_nil(tb.refetch_after) or tb.refetch_after < ^Timex.now())
      )
    else
      from(
        tb in __MODULE__,
        join: t in Token,
        on: tb.token_contract_address_hash == t.contract_address_hash,
        where:
          ((tb.address_hash != ^@burn_address_hash and t.type == "ERC-721") or t.type == "ERC-20" or t.type == "ZRC-2" or
             t.type == "ERC-1155" or t.type == "ERC-404") and
            (is_nil(tb.value_fetched_at) or is_nil(tb.value)) and
            (is_nil(tb.refetch_after) or tb.refetch_after < ^Timex.now())
      )
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch the token balance of the given token contract hash of the given address in the given block.
  """
  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, token_id \\ nil)

  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, nil) do
    from(
      tb in __MODULE__,
      where: tb.address_hash == ^address_hash,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.block_number <= ^block_number,
      limit: ^1,
      order_by: [desc: :block_number]
    )
  end

  def fetch_token_balance(address_hash, token_contract_address_hash, block_number, token_id) do
    from(
      tb in __MODULE__,
      where: tb.address_hash == ^address_hash,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.token_id == ^token_id,
      where: tb.block_number <= ^block_number,
      limit: ^1,
      order_by: [desc: :block_number]
    )
  end

  @doc """
  Deletes all token balances with given `token_contract_address_hash` and below the given `block_number`.
  Used for cases when token doesn't implement `balanceOf` function
  """
  @spec delete_placeholders_below(Hash.Address.t(), Block.block_number()) :: {non_neg_integer(), nil | [term()]}
  def delete_placeholders_below(token_contract_address_hash, block_number) do
    delete_token_balance_placeholders_below(__MODULE__, token_contract_address_hash, block_number)
  end

  @doc """
  Deletes all token balances or current token balances with given `token_contract_address_hash` and below the given `block_number`.
  Used for cases when token doesn't implement `balanceOf` function
  """
  @spec delete_token_balance_placeholders_below(atom(), Hash.Address.t(), Block.block_number()) ::
          {non_neg_integer(), nil | [term()]}
  def delete_token_balance_placeholders_below(module, token_contract_address_hash, block_number) do
    module
    |> where([tb], tb.token_contract_address_hash == ^token_contract_address_hash)
    |> where([tb], tb.block_number <= ^block_number)
    |> where([tb], is_nil(tb.value_fetched_at) or is_nil(tb.value))
    |> Repo.delete_all()
  end

  @doc """
  Returns a stream of all token balances that weren't fetched values.
  """
  @spec stream_unfetched_token_balances(
          initial :: accumulator,
          reducer :: (entry :: __MODULE__.t(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_token_balances(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    __MODULE__.unfetched_token_balances()
    |> add_token_balances_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  def add_token_balances_fetcher_limit(query, false), do: query

  def add_token_balances_fetcher_limit(query, true) do
    token_balances_fetcher_limit = Application.get_env(:indexer, :token_balances_fetcher_init_limit)

    limit(query, ^token_balances_fetcher_limit)
  end
end
