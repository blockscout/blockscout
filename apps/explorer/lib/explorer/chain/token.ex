defmodule Explorer.Chain.Token.Schema do
  @moduledoc false
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]

  alias Explorer.Chain.{Address, Address.Reputation, Hash}
  alias Explorer.Chain.Token.FiatValue

  if @bridged_tokens_enabled do
    @bridged_field [
      quote do
        field(:bridged, :boolean)
      end
    ]
  else
    @bridged_field []
  end

  defmacro generate do
    quote do
      @primary_key false
      typed_schema "tokens" do
        field(:name, :string)
        field(:symbol, :string)
        field(:total_supply, :decimal)
        field(:decimals, :decimal)
        field(:type, :string, null: false)
        field(:cataloged, :boolean)
        field(:holder_count, :integer)
        field(:skip_metadata, :boolean)
        field(:total_supply_updated_at_block, :integer)
        field(:metadata_updated_at, :utc_datetime_usec)
        field(:fiat_value, FiatValue)
        field(:circulating_market_cap, FiatValue)
        field(:icon_url, :string)
        field(:is_verified_via_admin_panel, :boolean)
        field(:volume_24h, FiatValue)
        field(:transfer_count, :integer)

        belongs_to(
          :contract_address,
          Address,
          foreign_key: :contract_address_hash,
          primary_key: true,
          references: :hash,
          type: Hash.Address,
          null: false
        )

        has_one(:reputation, Reputation, foreign_key: :address_hash, references: :contract_address_hash)

        unquote_splicing(@bridged_field)

        timestamps()
      end
    end
  end
end

defmodule Explorer.Chain.Token do
  @moduledoc """
  Represents a token.

  ## Token Indexing

  The following types of tokens are indexed:

  * ERC-20
  * ERC-721
  * ERC-1155
  * ERC-404
  * ZRC-2 (for Zilliqa chain type)
  * ERC-7984

  ## Token Specifications

  * [ERC-20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md)
  * [ERC-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md)
  * [ERC-777](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
  * [ERC-1155](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md)
  * [ERC-404](https://github.com/Pandora-Labs-Org/erc404)
  * [ZRC-2](https://github.com/Zilliqa/ZRC/blob/main/zrcs/zrc-2.md)
  * [ERC-7984](https://github.com/ethereum/ERCs/blob/39197cde3e32d8fc7fde74c7d0ce5e67ad4de409/ERCS/erc-7984.md)
  """
  require Logger

  use Explorer.Schema

  require Explorer.Chain.Token.Schema

  import Ecto.{Changeset, Query}

  alias Ecto.{Changeset, Multi}
  alias Explorer.{Chain, SortingHelper}
  alias Explorer.Chain.{Address, BridgedToken, Hash, Search, Token}
  alias Explorer.Chain.Cache.{BackgroundMigrations, BlockNumber}
  alias Explorer.Chain.Cache.Counters.{TokenHoldersCount, TokenTransfersCount}
  alias Explorer.Chain.Import.Runner
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Repo
  alias Explorer.SmartContract.Helper

  # milliseconds
  @timeout 60_000

  @default_sorting [
    desc_nulls_last: :circulating_market_cap,
    desc_nulls_last: :fiat_value,
    desc_nulls_last: :holder_count,
    asc: :name,
    asc: :contract_address_hash
  ]

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at,
             :metadata_updated_at
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :contract_address,
             :inserted_at,
             :updated_at,
             :metadata_updated_at
           ]}

  @typedoc """
  * `name` - Name of the token
  * `symbol` - Trading symbol of the token
  * `total_supply` - The total supply of the token
  * `decimals` - Number of decimal places the token can be subdivided to
  * `type` - Type of token
  * `cataloged` - Flag for if token information has been cataloged
  * `contract_address` - The `t:Address.t/0` of the token's contract
  * `contract_address_hash` - Address hash foreign key
  * `holder_count` - the number of `t:Explorer.Chain.Address.t/0` (except the burn address) that have a
    `t:Explorer.Chain.CurrentTokenBalance.t/0` `value > 0`.  Can be `nil` when data not migrated.
  * `transfer_count` - the number of token transfers for `t:Explorer.Chain.Address.t/0` token
  * `fiat_value` - The price of a token in a configured currency (USD by default).
  * `circulating_market_cap` - The circulating market cap of a token in a configured currency (USD by default).
  * `icon_url` - URL of the token's icon.
  * `is_verified_via_admin_panel` - is token verified via admin panel.
  """
  Explorer.Chain.Token.Schema.generate()

  @required_attrs ~w(contract_address_hash type)a
  @optional_attrs ~w(cataloged decimals name symbol total_supply skip_metadata total_supply_updated_at_block metadata_updated_at updated_at fiat_value circulating_market_cap icon_url is_verified_via_admin_panel volume_24h)a

  @doc """
    Returns the **ordered** list of allowed NFT type labels.
  """
  @spec allowed_nft_type_labels() :: [String.t()]
  def allowed_nft_type_labels,
    do: [
      "ERC-721",
      "ERC-1155",
      "ERC-404"
    ]

  @doc false
  def changeset(%Token{} = token, params \\ %{}) do
    additional_attrs = if BridgedToken.enabled?(), do: [:bridged], else: []

    token
    |> cast(params, @required_attrs ++ @optional_attrs ++ additional_attrs)
    |> validate_required(@required_attrs)
    |> trim_name()
    |> sanitize_token_input(:name)
    |> sanitize_token_input(:symbol)
    |> unique_constraint(:contract_address_hash)
  end

  defp trim_name(%Changeset{valid?: false} = changeset), do: changeset

  defp trim_name(%Changeset{valid?: true} = changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.trim(name))
    end
  end

  defp sanitize_token_input(%Changeset{valid?: false} = changeset, _), do: changeset

  defp sanitize_token_input(%Changeset{valid?: true} = changeset, key) do
    case get_change(changeset, key) do
      nil ->
        changeset

      property ->
        put_change(changeset, key, Helper.escape_minimal(property))
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch the cataloged tokens.

  These are tokens with cataloged field set to true, skip_metadata is not true and metadata_updated_at is earlier or equal than 48 hours ago.
  """
  def cataloged_tokens(minutes \\ 2880) do
    date_now = DateTime.utc_now()
    some_time_ago_date = DateTime.add(date_now, -:timer.minutes(minutes), :millisecond)

    from(
      token in __MODULE__,
      where: token.cataloged == true,
      where: is_nil(token.metadata_updated_at) or token.metadata_updated_at <= ^some_time_ago_date,
      where: is_nil(token.skip_metadata) or token.skip_metadata == false
    )
  end

  @doc """
  Streams a list of tokens that have been cataloged for their metadata update.
  """
  @spec stream_cataloged_tokens(
          initial :: accumulator,
          reducer :: (entry :: __MODULE__.t(), accumulator -> accumulator),
          some_time_ago_updated :: integer(),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_cataloged_tokens(initial, reducer, some_time_ago_updated \\ 2880, limited? \\ false)
      when is_function(reducer, 2) do
    some_time_ago_updated
    |> cataloged_tokens()
    |> Chain.add_fetcher_limit(limited?)
    |> order_by(asc_nulls_first: :metadata_updated_at)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Update a new `t:Token.t/0` record.

  As part of updating token, an additional record is inserted for
  naming the address for reference if a name is provided for a token.
  """
  @spec update(__MODULE__.t(), map(), boolean(), :base | :metadata_update) ::
          {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def update(
        %__MODULE__{contract_address_hash: address_hash} = token,
        params \\ %{},
        info_from_admin_panel? \\ false,
        operation_type \\ :base
      ) do
    params =
      if Map.has_key?(params, :total_supply) do
        Map.put(params, :total_supply_updated_at_block, BlockNumber.get_max())
      else
        params
      end

    filtered_params = for({key, value} <- params, value !== "" && !is_nil(value), do: {key, value}) |> Enum.into(%{})

    token_changeset =
      token
      |> __MODULE__.changeset(
        filtered_params
        |> Map.put(:updated_at, DateTime.utc_now())
      )
      |> (&if(token.is_verified_via_admin_panel && !info_from_admin_panel?,
            do: &1 |> Changeset.delete_change(:symbol) |> Changeset.delete_change(:name),
            else: &1
          )).()

    address_name_changeset =
      Address.Name.changeset(%Address.Name{}, Map.put(filtered_params, :address_hash, address_hash))

    stale_error_field = :contract_address_hash
    stale_error_message = "is up to date"

    on_conflict =
      if operation_type == :metadata_update do
        token_metadata_update_on_conflict()
      else
        Runner.Tokens.default_on_conflict()
      end

    token_opts = [
      on_conflict: on_conflict,
      conflict_target: :contract_address_hash,
      stale_error_field: stale_error_field,
      stale_error_message: stale_error_message
    ]

    address_name_opts = [on_conflict: :nothing, conflict_target: [:address_hash, :name]]

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_result =
      Multi.new()
      |> Multi.run(
        :address_name,
        fn repo, _ ->
          {:ok, repo.insert(address_name_changeset, address_name_opts)}
        end
      )
      |> Multi.run(:token, fn repo, _ ->
        with {:error, %Changeset{errors: [{^stale_error_field, {^stale_error_message, [_]}}]}} <-
               repo.update(token_changeset, token_opts) do
          # the original token passed into `update/2` as stale error means it is unchanged
          {:ok, token}
        end
      end)
      |> Repo.transaction()

    case insert_result do
      {:ok, %{token: token}} ->
        {:ok, token}

      {:error, :token, changeset, _} ->
        {:error, changeset}
    end
  end

  defp token_metadata_update_on_conflict do
    from(
      token in Token,
      update: [
        set: [
          name: fragment("COALESCE(EXCLUDED.name, ?)", token.name),
          symbol: fragment("COALESCE(EXCLUDED.symbol, ?)", token.symbol),
          total_supply: fragment("COALESCE(EXCLUDED.total_supply, ?)", token.total_supply),
          decimals: fragment("COALESCE(EXCLUDED.decimals, ?)", token.decimals),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token.updated_at),
          metadata_updated_at: fragment("GREATEST(?, EXCLUDED.metadata_updated_at)", token.metadata_updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.symbol, EXCLUDED.total_supply, EXCLUDED.decimals) IS DISTINCT FROM (?, ?, ?, ?)",
          token.name,
          token.symbol,
          token.total_supply,
          token.decimals
        )
    )
  end

  def tokens_by_contract_address_hashes(contract_address_hashes) do
    from(token in __MODULE__, where: token.contract_address_hash in ^contract_address_hashes)
  end

  def base_token_query(type, sorting) do
    query = from(t in Token, preload: [:contract_address])

    query |> apply_filter(type) |> SortingHelper.apply_sorting(sorting, @default_sorting)
  end

  def default_sorting, do: @default_sorting

  @doc """
  Lists the top `t:__MODULE__.t/0`'s'.
  """
  @spec list_top(String.t() | nil, [
          Chain.paging_options()
          | {:sorting, SortingHelper.sorting_params()}
          | {:token_type, [String.t()]}
          | {:necessity_by_association, map()}
          | Chain.show_scam_tokens?()
        ]) :: [__MODULE__.t()]
  def list_top(filter, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    token_type = Keyword.get(options, :token_type, nil)
    sorting = Keyword.get(options, :sorting, [])

    necessity_by_association =
      Keyword.get(options, :necessity_by_association, %{
        :contract_address => :optional
      })

    sorted_paginated_query =
      Token
      |> Chain.join_associations(necessity_by_association)
      |> ExplorerHelper.maybe_hide_scam_addresses_with_select(:contract_address_hash, options)
      |> apply_filter(token_type)
      |> SortingHelper.apply_sorting(sorting, @default_sorting)
      |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)

    filtered_query =
      case filter && filter !== "" && Search.prepare_search_term(filter) do
        {:some, filter_term} ->
          sorted_paginated_query
          |> apply_fts_filter(filter_term)

        _ ->
          sorted_paginated_query
      end

    filtered_query
    |> Chain.select_repo(options).all()
  end

  @doc """
  Applies full-text search filtering to a token query.

  This function handles tokens with and without symbols differently:
  - For tokens with a symbol, it searches across both symbol and name.
  - For tokens without a symbol (e.g., ERC-1155), it searches only the name field.

  ## Parameters
  - `query`: The Ecto query to filter.
  - `filter_term`: The prepared search term (from Search.prepare_search_term/1).

  ## Returns
  - An Ecto query with FTS filtering applied.
  """
  @spec apply_fts_filter(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def apply_fts_filter(query, filter_term) do
    if BackgroundMigrations.get_heavy_indexes_create_tokens_name_partial_fts_index_finished() do
      query
      |> where(
        [token],
        (not is_nil(token.symbol) and
           fragment(
             "to_tsvector('english', ? || ' ' || ?) @@ to_tsquery(?)",
             token.symbol,
             token.name,
             ^filter_term
           )) or
          (is_nil(token.symbol) and
             fragment(
               "to_tsvector('english', ?) @@ to_tsquery(?)",
               token.name,
               ^filter_term
             ))
      )
    else
      query
      |> where(
        [token],
        fragment("to_tsvector('english', ? || ' ' || ?) @@ to_tsquery(?)", token.symbol, token.name, ^filter_term)
      )
    end
  end

  defp apply_filter(query, empty_type) when empty_type in [nil, []], do: query

  defp apply_filter(query, token_types) when is_list(token_types) do
    from(t in query, where: t.type in ^token_types)
  end

  def get_by_contract_address_hash(hash, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    __MODULE__
    |> where([t], t.contract_address_hash == ^hash)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).one()
  end

  @doc """
    Gets tokens with given contract address hashes.
  """
  @spec get_by_contract_address_hashes([Hash.Address.t()], [Chain.api?() | Chain.necessity_by_association_option()]) ::
          [__MODULE__.t()]
  def get_by_contract_address_hashes(hashes, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    __MODULE__
    |> where([t], t.contract_address_hash in ^hashes)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
  end

  @doc """
    For usage in Indexer.Fetcher.TokenInstance.SanitizeERC721
  """
  @spec ordered_erc_721_token_address_hashes_list_query(integer(), Hash.Address.t() | nil) :: Ecto.Query.t()
  def ordered_erc_721_token_address_hashes_list_query(limit, last_address_hash \\ nil) do
    query =
      __MODULE__
      |> order_by([token], asc: token.contract_address_hash)
      |> where([token], token.type == "ERC-721")
      |> limit(^limit)
      |> select([token], token.contract_address_hash)

    (last_address_hash && where(query, [token], token.contract_address_hash > ^last_address_hash)) || query
  end

  @doc """
    Updates token_holder_count for a given contract_address_hash.
    It used by Explorer.Chain.Cache.Counters.TokenHoldersCount module.
  """
  @spec update_token_holder_count(Hash.Address.t(), integer()) :: {non_neg_integer(), nil}
  def update_token_holder_count(contract_address_hash, holders_count) when not is_nil(holders_count) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(t in __MODULE__,
        where: t.contract_address_hash == ^contract_address_hash,
        update: [set: [holder_count: ^holders_count, updated_at: ^now]]
      ),
      [],
      timeout: @timeout
    )
  end

  @doc """
    Updates `transfer_count` field for a given `contract_address_hash`.
    Used by the `Explorer.Chain.Cache.Counters.TokenTransfersCount` module.

    ## Parameters
    - `contract_address_hash`: The address of the token contract.
    - `transfer_count`: The updated counter value.

    ## Returns
    - `{updated_count, nil}` tuple where `updated_count` is the number of updated rows in the db table.
  """
  @spec update_token_transfer_count(Hash.Address.t(), non_neg_integer()) :: {non_neg_integer(), nil}
  def update_token_transfer_count(contract_address_hash, transfer_count) when not is_nil(transfer_count) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(t in __MODULE__,
        where: t.contract_address_hash == ^contract_address_hash,
        update: [set: [transfer_count: ^transfer_count, updated_at: ^now]]
      ),
      [],
      timeout: @timeout
    )
  end

  @doc """
  Drops token info for the given token:
  Sets is_verified_via_admin_panel to false, icon_url to nil, symbol to nil, name to nil.
  Don't forget to set/update token's symbol and name after this function.
  """
  @spec drop_token_info(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def drop_token_info(token) do
    token
    |> Changeset.change(%{is_verified_via_admin_panel: false, icon_url: nil, symbol: nil, name: nil})
    |> Repo.update()
  end

  @doc """
  Returns query for token by contract address hash
  """
  @spec token_by_contract_address_hash_query(binary() | Hash.Address.t()) :: Ecto.Query.t()
  def token_by_contract_address_hash_query(contract_address_hash) do
    __MODULE__
    |> where([token], token.contract_address_hash == ^contract_address_hash)
  end

  @doc """
  Checks if a token with the given contract address hash exists.

  ## Parameters

    - hash: The contract address hash to check for.
    - options: Options to select the repository.

  ## Returns

  - `true` if a token with the given contract address hash exists.
  - `false` otherwise.
  """
  @spec by_contract_address_hash_exists?(Hash.Address.t() | String.t(), [Chain.api?()]) :: boolean()
  def by_contract_address_hash_exists?(hash, options) do
    query =
      from(
        t in __MODULE__,
        where: t.contract_address_hash == ^hash
      )

    Chain.select_repo(options).exists?(query)
  end

  @doc """
  Checks if the given token is ZRC-2 token.

  ## Parameters
  - `token`: The token to check the type of.

  ## Returns
  - `true` if this is ZRC-2 token, `false` otherwise.
  """
  @spec zrc_2_token?(__MODULE__.t()) :: bool
  def zrc_2_token?(token) do
    case Map.get(token, :type) do
      "ZRC-2" -> true
      _ -> false
    end
  end

  @doc """
  Fetches token counters (transfers count and holders count) for a given token address.

  This function spawns two async tasks to fetch the token transfers count and
  token holders count concurrently. If a task times out or exits, it falls back
  to fetching the cached value.

  ## Parameters
  - `address_hash`: The contract address hash of the token
  - `timeout`: The timeout in milliseconds for the async tasks

  ## Returns
  - A tuple `{transfers_count, holders_count}` where each value is an integer or nil
  """
  @spec fetch_token_counters(Hash.Address.t(), timeout()) :: {integer() | nil, integer() | nil}
  def fetch_token_counters(address_hash, timeout) do
    total_token_transfers_task =
      Task.async(fn ->
        TokenTransfersCount.fetch(address_hash)
      end)

    total_token_holders_task =
      Task.async(fn ->
        TokenHoldersCount.fetch(address_hash)
      end)

    [total_token_transfers_task, total_token_holders_task]
    |> Task.yield_many(timeout)
    |> Enum.map(fn {task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          Logger.warning("Query fetching token counters terminated: #{inspect(reason)}")

          fallback_cached_value_based_on_async_task_pid(
            task.pid,
            total_token_transfers_task.pid,
            total_token_holders_task.pid,
            address_hash
          )

        nil ->
          Logger.warning("Query fetching token counters timed out.")

          fallback_cached_value_based_on_async_task_pid(
            task.pid,
            total_token_transfers_task.pid,
            total_token_holders_task.pid,
            address_hash
          )
      end
    end)
    |> List.to_tuple()
  end

  defp fallback_cached_value_based_on_async_task_pid(
         task_pid,
         total_token_transfers_task_pid,
         total_token_holders_task_pid,
         address_hash
       ) do
    case task_pid do
      ^total_token_transfers_task_pid ->
        TokenTransfersCount.fetch_count_from_cache(address_hash)

      ^total_token_holders_task_pid ->
        TokenHoldersCount.fetch_count_from_cache(address_hash)
    end
  end

  @doc """
  Checks if a `t:Explorer.Chain.Token.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> address = insert(:address)
      iex> insert(:token, contract_address: address)
      iex> Explorer.Chain.Token.check_token_exists(address.hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.Token.check_token_exists(hash)
      :not_found
  """
  @spec check_token_exists(Hash.Address.t()) :: :ok | :not_found
  def check_token_exists(hash) do
    hash
    |> token_exists?()
    |> Chain.boolean_to_check_result()
  end

  # Checks if a `t:Explorer.Chain.Token.t/0` with the given `hash` exists.

  # Returns `true` if found

  #     iex> address = insert(:address)
  #     iex> insert(:token, contract_address: address)
  #     iex> Explorer.Chain.token_exists?(address.hash)
  #     true

  # Returns `false` if not found

  #     iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
  #     iex> Explorer.Chain.token_exists?(hash)
  #     false
  @spec token_exists?(Hash.Address.t()) :: boolean()
  defp token_exists?(hash) do
    query =
      from(
        token in Token,
        where: token.contract_address_hash == ^hash
      )

    Repo.exists?(query)
  end

  @doc """
  Gets the token type for a given contract address hash.
  """
  @spec get_token_type(Hash.Address.t()) :: String.t() | nil
  def get_token_type(hash) do
    query =
      from(
        token in __MODULE__,
        where: token.contract_address_hash == ^hash,
        select: token.type
      )

    Repo.one(query)
  end

  @doc """
  Gets the token types for a list of contract address hashes.
  """
  @spec get_token_types([Hash.Address.t()]) :: [{Hash.Address.t(), String.t()}]
  def get_token_types(hashes) do
    query =
      from(
        token in __MODULE__,
        where: token.contract_address_hash in ^hashes,
        select: {token.contract_address_hash, token.type}
      )

    Repo.all(query)
  end
end
