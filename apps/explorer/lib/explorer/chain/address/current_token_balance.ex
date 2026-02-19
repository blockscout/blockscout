defmodule Explorer.Chain.Address.CurrentTokenBalance do
  @moduledoc """
  Represents the current token balance from addresses according to the last block.

  In this table we can see only the last balance from addresses. If you want to see the history of
  token balances look at the `Address.TokenBalance` instead.
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, limit: 2, offset: 2, order_by: 3, preload: 2, dynamic: 2]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]
  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, CurrencyHelper, Hash, Token}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Cache.BackgroundMigrations

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
   *  `address` - The `t:Explorer.Chain.Address.t/0` that is the balance's owner.
   *  `address_hash` - The address hash foreign key.
   *  `token` - The `t:Explorer.Chain.Token/0` so that the address has the balance.
   *  `token_contract_address_hash` - The contract address hash foreign key.
   *  `block_number` - The block's number that the transfer took place.
   *  `value` - The value that's represents the balance.
   *  `token_id` - The token_id of the transferred token (applicable for ERC-1155)
   *  `token_type` - The type of the token
   *  `refetch_after` - when to refetch the balance
   *  `retries_count` - number of times the balance has been retried
  """
  typed_schema "address_current_token_balances" do
    field(:value, :decimal)
    field(:block_number, :integer) :: Block.block_number()
    field(:max_block_number, :integer, virtual: true) :: Block.block_number()
    field(:value_fetched_at, :utc_datetime_usec)
    field(:token_id, :decimal)
    field(:token_type, :string, null: false)
    field(:fiat_value, :decimal, virtual: true)
    field(:distinct_token_instances_count, :integer, virtual: true)
    field(:token_ids, {:array, :decimal}, virtual: true)
    field(:preloaded_token_instances, {:array, :any}, virtual: true)
    field(:refetch_after, :utc_datetime_usec)
    field(:retries_count, :integer)

    # A transient field for deriving token holder count deltas during address_current_token_balances upserts
    field(:old_value, :decimal)

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
  end

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
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
    token_contract_address_hash
    |> token_holders_ordered_by_value_query_without_address_preload(options)
    |> preload(address: [:names, :smart_contract, ^proxy_implementations_association()])
  end

  @doc """
  Do the same as token_holders_ordered_by_value/2, but `|> preload(:address)` removed
  """
  def token_holders_ordered_by_value_query_without_address_preload(token_contract_address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, _}} ->
        []

      _ ->
        offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

        token_contract_address_hash
        |> token_holders_query()
        |> order_by([tb], desc: :value, desc: :address_hash)
        |> Chain.page_token_balances(paging_options)
        |> limit(^paging_options.page_size)
        |> offset(^offset)
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch the token holders from the given token contract address hash and token_id.

  The Token Holders are the addresses that own a positive amount of the Token. So this query is
  considering the following conditions:

  * The token balance from the last block.
  * Balances greater than 0.
  * Excluding the burn address (0x0000000000000000000000000000000000000000).

  """
  def token_holders_1155_by_token_id(token_contract_address_hash, token_id, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, _}} ->
        []

      _ ->
        token_contract_address_hash
        |> token_holders_by_token_id_query(token_id)
        |> preload(address: [:names, :smart_contract, ^proxy_implementations_association()])
        |> order_by([tb], desc: :value, desc: :address_hash)
        |> Chain.page_token_balances(paging_options)
        |> limit(^paging_options.page_size)
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch all available token_ids
  """
  def token_ids_query(token_contract_address_hash) do
    from(
      ctb in __MODULE__,
      where: ctb.token_contract_address_hash == ^token_contract_address_hash,
      where: ctb.address_hash != ^@burn_address_hash,
      where: ctb.value > 0,
      select: ctb.token_id,
      distinct: ctb.token_id
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch all token holders, to count it
  Used in `Explorer.Chain.Address.CurrentTokenBalance.count_token_holders_from_token_hash/1`
  """
  def token_holders_query_for_count(token_contract_address_hash) do
    from(
      ctb in __MODULE__,
      where: ctb.token_contract_address_hash == ^token_contract_address_hash,
      where: ctb.address_hash != ^@burn_address_hash,
      where: ctb.value > 0 or ctb.token_type == "ERC-7984"
    )
  end

  def fiat_value_query do
    dynamic([ctb, t], ctb.value * t.fiat_value / fragment("10 ^ ?", t.decimals))
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current token balances of the given addresses (include unfetched).
  """
  def last_token_balances_include_unfetched(address_hashes) do
    fiat_balance = fiat_value_query()

    from(
      ctb in __MODULE__,
      where: ctb.address_hash in ^address_hashes,
      where: ctb.token_type != "ERC-7984",
      left_join: t in assoc(ctb, :token),
      on: ctb.token_contract_address_hash == t.contract_address_hash,
      preload: [token: t],
      select: ctb,
      select_merge: ^%{fiat_value: fiat_balance}
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current token balances of the given address.
  """
  def last_token_balances(address_hash, type \\ [])

  def last_token_balances(address_hash, types) when is_list(types) and types != [] do
    fiat_balance = fiat_value_query()

    from(
      ctb in __MODULE__,
      where: ctb.address_hash == ^address_hash,
      where: ctb.value > 0 or ctb.token_type == "ERC-7984",
      left_join: t in assoc(ctb, :token),
      on: ctb.token_contract_address_hash == t.contract_address_hash,
      preload: [token: t],
      where: t.type in ^types,
      select: ctb,
      select_merge: ^%{fiat_value: fiat_balance},
      order_by: ^[desc_nulls_last: fiat_balance],
      order_by: [desc: ctb.value, desc: ctb.id]
    )
  end

  def last_token_balances(address_hash, _) do
    fiat_balance = fiat_value_query()

    from(
      ctb in __MODULE__,
      where: ctb.address_hash == ^address_hash,
      where: ctb.value > 0 or ctb.token_type == "ERC-7984",
      left_join: t in assoc(ctb, :token),
      on: ctb.token_contract_address_hash == t.contract_address_hash,
      preload: [token: t],
      select: ctb,
      select_merge: ^%{fiat_value: fiat_balance},
      order_by: ^[desc_nulls_last: fiat_balance],
      order_by: [desc: ctb.value, desc: ctb.id]
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current token balances of the given address (paginated version).
  """
  def last_token_balances(address_hash, options, type) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> last_token_balances(type)
    |> limit(^paging_options.page_size)
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current balance of the given address for the given token.
  """
  def last_token_balance(address_hash, token_contract_address_hash) do
    query =
      from(
        tb in __MODULE__,
        where: tb.token_contract_address_hash == ^token_contract_address_hash,
        where: tb.address_hash == ^address_hash,
        select: tb.value
      )

    query
    |> Repo.one()
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current balance of the given address for the given token and token_id
  """
  def last_token_balance_1155(address_hash, token_contract_address_hash, token_id) do
    query =
      from(
        ctb in __MODULE__,
        where: ctb.token_contract_address_hash == ^token_contract_address_hash,
        where: ctb.address_hash == ^address_hash,
        where: ctb.token_id == ^token_id,
        select: ctb.value
      )

    query
    |> Repo.one()
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to check if the token_id corresponds to the unique token or not.
  Used in `Explorer.Chain.token_id_1155_is_unique?/2`
  """
  def token_balances_by_id_limit_2(token_contract_address_hash, token_id) do
    from(
      ctb in __MODULE__,
      where: ctb.token_contract_address_hash == ^token_contract_address_hash,
      where: ctb.token_id == ^token_id,
      where: ctb.address_hash != ^@burn_address_hash,
      where: ctb.value > 0,
      select: ctb.value,
      limit: 2
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch holders of the particular token_id in ERC-1155
  """
  def token_holders_by_token_id_query(token_contract_address_hash, token_id) do
    from(
      ctb in __MODULE__,
      where: ctb.token_contract_address_hash == ^token_contract_address_hash,
      where: ctb.address_hash != ^@burn_address_hash,
      where: ctb.value > 0,
      where: ctb.token_id == ^token_id
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch addresses that hold the token.

  Token holders cannot be the burn address (#{@burn_address_hash}) and must have a non-zero value or be an ERC-7984 token.
  """
  def token_holders_query(token_contract_address_hash) do
    from(
      tb in __MODULE__,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.address_hash != ^@burn_address_hash,
      where: tb.value > 0 or tb.token_type == "ERC-7984"
    )
  end

  @spec count_token_holders_from_token_hash(Hash.Address.t()) :: non_neg_integer()
  def count_token_holders_from_token_hash(contract_address_hash) do
    query =
      from(ctb in __MODULE__.token_holders_query_for_count(contract_address_hash),
        select: fragment("COUNT(DISTINCT(?))", ctb.address_hash)
      )

    Repo.one!(query, timeout: :infinity)
  end

  @doc """
  Deletes all CurrentTokenBalances with given `token_contract_address_hash` and below the given `block_number`.
  Used for cases when token doesn't implement balanceOf function
  """
  @spec delete_placeholders_below(Hash.Address.t(), Block.block_number()) :: {non_neg_integer(), nil | [term()]}
  def delete_placeholders_below(token_contract_address_hash, block_number) do
    TokenBalance.delete_token_balance_placeholders_below(__MODULE__, token_contract_address_hash, block_number)
  end

  @doc """
  Converts CurrentTokenBalances to CSV format. Used in `BlockScoutWeb.API.V2.CsvExportController.export_token_holders/2`
  """
  @spec to_csv_format([t()], Token.t()) :: (any(), any() -> {:halted, any()} | {:suspended, any(), (any() -> any())})
  def to_csv_format(holders, token) do
    row_names = [
      "HolderAddress",
      "Balance"
    ]

    holders_list =
      holders
      |> Stream.map(fn ctb ->
        [
          Address.checksum(ctb.address_hash),
          ctb.value |> CurrencyHelper.divide_decimals(token.decimals) |> Decimal.to_string(:xsd)
        ]
      end)

    Stream.concat([row_names], holders_list)
  end

  @doc """
  Returns a stream of all current token balances that weren't fetched values.
  """
  @spec stream_unfetched_current_token_balances(
          initial :: accumulator,
          reducer :: (entry :: __MODULE__.t(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_current_token_balances(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    unfetched_current_token_balances()
    |> TokenBalance.add_token_balances_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Builds an `Ecto.Query` to fetch the unfetched current token balances.

  Unfetched current token balances are the ones that have the column `value_fetched_at` nil or the value is null. This query also
  ignores the burn_address for tokens ERC-721 since the most tokens ERC-721 don't allow get the
  balance for burn_address.
  """
  # credo:disable-for-next-line /Complexity/
  def unfetched_current_token_balances do
    if BackgroundMigrations.get_ctb_token_type_finished() do
      from(
        ctb in __MODULE__,
        where:
          ((ctb.address_hash != ^@burn_address_hash and ctb.token_type == "ERC-721") or ctb.token_type == "ERC-20" or
             ctb.token_type == "ZRC-2" or
             ctb.token_type == "ERC-1155" or ctb.token_type == "ERC-404") and
            (is_nil(ctb.value_fetched_at) or is_nil(ctb.value)) and
            (is_nil(ctb.refetch_after) or ctb.refetch_after < ^Timex.now())
      )
    else
      from(
        ctb in __MODULE__,
        join: t in Token,
        on: ctb.token_contract_address_hash == t.contract_address_hash,
        where:
          ((ctb.address_hash != ^@burn_address_hash and t.type == "ERC-721") or t.type == "ERC-20" or t.type == "ZRC-2" or
             t.type == "ERC-1155" or t.type == "ERC-404") and
            (is_nil(ctb.value_fetched_at) or is_nil(ctb.value)) and
            (is_nil(ctb.refetch_after) or ctb.refetch_after < ^Timex.now())
      )
    end
  end
end
