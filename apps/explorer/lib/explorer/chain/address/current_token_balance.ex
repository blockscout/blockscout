# SPDX-License-Identifier: LicenseRef-Blockscout
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
  alias Explorer.Chain.{Address, Block, Hash, SmartContract, Token}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Utility.MissingBalanceOfToken

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

  @fungible_token_types ~w(ERC-20 ERC-8056)

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

  @doc """
  Builds a `t:Ecto.Query.dynamic_expr/0` for the fiat value of a token balance.

  `tokens.fiat_value` is the price of one *displayed* unit of the token, which
  for an [ERC-8056](https://eips.ethereum.org/EIPS/eip-8056) token is not the
  same as one raw unit: what trades, and what a price source therefore quotes,
  is the UI amount. So the raw balance is scaled by the multiplier before it is
  priced, and the `CASE` falls back to `1e18` — a multiplier of exactly one —
  for every token that does not implement the standard.

  The branch mirrors `Explorer.Chain.Token.effective_ui_multiplier/2`: a
  scheduled change takes effect with nothing happening on chain and nothing
  written to the database, so which of the two stored values applies has to be
  decided against the clock. It is the database clock here rather than the
  application's, which keeps the expression free of a timestamp parameter; both
  are UTC and the difference between them is far below the resolution at which
  a multiplier change matters.

  Expects the `tokens` table as the second binding.
  """
  @spec fiat_value_query() :: Ecto.Query.dynamic_expr()
  def fiat_value_query do
    dynamic(
      [ctb, t],
      fragment(
        """
        ? * CASE
              WHEN ? IS NULL THEN 1000000000000000000
              WHEN ? IS NOT NULL AND ? IS NOT NULL AND ? <= (now() AT TIME ZONE 'utc') THEN ?
              ELSE ?
            END * ? / (10 ^ ?) / 1000000000000000000
        """,
        ctb.value,
        t.ui_multiplier,
        t.new_ui_multiplier,
        t.ui_multiplier_effective_at,
        t.ui_multiplier_effective_at,
        t.new_ui_multiplier,
        t.ui_multiplier,
        t.fiat_value,
        t.decimals
      )
    )
  end

  @doc """
  Builds an `t:Ecto.Query.t/0` to fetch the current token balances of the given addresses (include unfetched)
  with `block_number` older than the given stale balance window.
  """
  def last_token_balances_include_unfetched(address_hashes, stale_balance_window) when is_list(address_hashes) do
    fiat_balance = fiat_value_query()

    from(
      ctb in __MODULE__,
      where: ctb.address_hash in ^address_hashes,
      where: ctb.token_type != "ERC-7984",
      where: ctb.block_number < ^stale_balance_window,
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

  Token holders must have a non-zero value or be an ERC-7984 token. The burn
  address (#{@burn_address_hash}) is listed only for fungible tokens
  (#{Enum.join(@fungible_token_types, ", ")}), where its balance is supply sent
  there without lowering `totalSupply()`. It is still not counted in
  `tokens.holder_count`, see `token_holders_query_for_count/1`.
  """
  def token_holders_query(token_contract_address_hash) do
    from(
      tb in __MODULE__,
      where: tb.token_contract_address_hash == ^token_contract_address_hash,
      where: tb.address_hash != ^@burn_address_hash or tb.token_type in ^@fungible_token_types,
      where: tb.value > 0 or tb.token_type == "ERC-7984"
    )
  end

  @typedoc """
  Current balance row of a burn address, see `burn_address_balances/2`. The
  balance at `block_number` is fetched only when `value_fetched_at` is set: a
  transfer in a newer block moves `block_number` forward and clears
  `value_fetched_at`, but keeps the previous `value` until the new balance is
  read. `value` is `nil` while no balance was ever fetched; `retries_count` and
  `refetch_after` then describe the backoff of failed fetches.
  """
  @type burn_address_balance :: %{
          value: Decimal.t() | nil,
          value_fetched_at: DateTime.t() | nil,
          block_number: Block.block_number(),
          retries_count: non_neg_integer() | nil,
          refetch_after: DateTime.t() | nil
        }

  @doc """
  Returns the current balance rows of `token_contract_address_hash` for the burn
  addresses (#{Enum.join(SmartContract.burn_address_hash_strings(), ", ")}),
  keyed by address hash. Addresses without a row are absent from the map; rows
  whose balance is not fetched yet have a `nil` value.
  """
  @spec burn_address_balances(Hash.Address.t(), [Chain.api?()]) :: %{Hash.Address.t() => burn_address_balance()}
  def burn_address_balances(token_contract_address_hash, options \\ []) do
    burn_address_hashes = SmartContract.burn_address_hashes()

    query =
      from(
        ctb in __MODULE__,
        where: ctb.token_contract_address_hash == ^token_contract_address_hash,
        where: ctb.address_hash in ^burn_address_hashes,
        where: is_nil(ctb.token_id),
        select:
          {ctb.address_hash,
           %{
             value: ctb.value,
             value_fetched_at: ctb.value_fetched_at,
             block_number: ctb.block_number,
             retries_count: ctb.retries_count,
             refetch_after: ctb.refetch_after
           }}
      )

    query
    |> Chain.select_repo(options).all()
    |> Map.new()
  end

  @doc """
  Records failed backfill reads of current token balances: inserts the missing
  rows as unfetched balances with the given `retries_count` and `refetch_after`,
  and updates those two fields on rows that were never fetched (`value` and
  `value_fetched_at` both `nil`).

  A row that has a value, fetched before or meanwhile, is left unchanged, and so
  is the retry state of a newer attempt: an update must raise `retries_count`,
  or keep it and move `refetch_after` later.

  ## Parameters
  - `params`: maps with `address_hash` and `token_contract_address_hash` (hash
    structs or hex strings), `token_type`, `block_number`, `retries_count` and
    `refetch_after`, for balances without a token id.

  ## Returns
  - the number of inserted or updated rows.
  """
  @spec record_backfill_failures([map()]) :: non_neg_integer()
  def record_backfill_failures([]), do: 0

  def record_backfill_failures(params) do
    now = DateTime.utc_now()

    rows =
      params
      |> Enum.map(fn param ->
        {:ok, address_hash} = Hash.Address.cast(param.address_hash)
        {:ok, token_contract_address_hash} = Hash.Address.cast(param.token_contract_address_hash)

        %{
          address_hash: address_hash,
          token_contract_address_hash: token_contract_address_hash,
          token_type: param.token_type,
          block_number: param.block_number
        }
        |> Map.merge(%{
          token_id: nil,
          value: nil,
          value_fetched_at: nil,
          retries_count: param.retries_count,
          refetch_after: param.refetch_after,
          inserted_at: now,
          updated_at: now
        })
      end)
      |> Enum.uniq_by(&{&1.address_hash, &1.token_contract_address_hash})
      # Enforce CurrentTokenBalance ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id, &1.address_hash})

    on_conflict =
      from(
        ctb in __MODULE__,
        update: [
          set: [
            retries_count: fragment("EXCLUDED.retries_count"),
            refetch_after: fragment("EXCLUDED.refetch_after"),
            updated_at: fragment("EXCLUDED.updated_at")
          ]
        ],
        where:
          is_nil(ctb.value) and is_nil(ctb.value_fetched_at) and
            fragment(
              "(? IS NULL OR EXCLUDED.retries_count > ? OR (EXCLUDED.retries_count = ? AND EXCLUDED.refetch_after > ?))",
              ctb.retries_count,
              ctb.retries_count,
              ctb.retries_count,
              ctb.refetch_after
            )
      )

    {count, _} =
      Repo.insert_all(__MODULE__, rows,
        on_conflict: on_conflict,
        conflict_target: {:unsafe_fragment, ~s<(address_hash, token_contract_address_hash, COALESCE(token_id, -1))>}
      )

    count
  end

  @doc """
  Returns the token types whose burn address balance is indexed and reported as
  burned supply.
  """
  @spec fungible_token_types() :: [String.t()]
  def fungible_token_types, do: @fungible_token_types

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
    |> MissingBalanceOfToken.filter_token_balances_query()
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
             ctb.token_type == "ERC-8056" or
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
          ((ctb.address_hash != ^@burn_address_hash and t.type == "ERC-721") or t.type == "ERC-20" or
             t.type == "ERC-8056" or t.type == "ZRC-2" or
             t.type == "ERC-1155" or t.type == "ERC-404") and
            (is_nil(ctb.value_fetched_at) or is_nil(ctb.value)) and
            (is_nil(ctb.refetch_after) or ctb.refetch_after < ^Timex.now())
      )
    end
  end
end
