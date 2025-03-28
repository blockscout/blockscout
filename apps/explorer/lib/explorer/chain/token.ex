defmodule Explorer.Chain.Token.Schema do
  @moduledoc false
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]

  alias Explorer.Chain.{Address, Hash}

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
        field(:fiat_value, :decimal)
        field(:circulating_market_cap, :decimal)
        field(:icon_url, :string)
        field(:is_verified_via_admin_panel, :boolean)
        field(:volume_24h, :decimal)

        belongs_to(
          :contract_address,
          Address,
          foreign_key: :contract_address_hash,
          primary_key: true,
          references: :hash,
          type: Hash.Address,
          null: false
        )

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

  ## Token Specifications

  * [ERC-20](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md)
  * [ERC-721](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md)
  * [ERC-777](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
  * [ERC-1155](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1155.md)
  * [ERC-404](https://github.com/Pandora-Labs-Org/erc404)
  """

  use Explorer.Schema

  require Explorer.Chain.Token.Schema

  import Ecto.{Changeset, Query}

  alias Ecto.{Changeset, Multi}
  alias Explorer.{Chain, SortingHelper}
  alias Explorer.Chain.{Address, BridgedToken, Hash, Search, Token}
  alias Explorer.Chain.Cache.BlockNumber
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
  * `fiat_value` - The price of a token in a configured currency (USD by default).
  * `circulating_market_cap` - The circulating market cap of a token in a configured currency (USD by default).
  * `icon_url` - URL of the token's icon.
  * `is_verified_via_admin_panel` - is token verified via admin panel.
  """
  Explorer.Chain.Token.Schema.generate()

  @required_attrs ~w(contract_address_hash type)a
  @optional_attrs ~w(cataloged decimals name symbol total_supply skip_metadata total_supply_updated_at_block metadata_updated_at updated_at fiat_value circulating_market_cap icon_url is_verified_via_admin_panel volume_24h)a

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
        put_change(changeset, key, Helper.sanitize_input(property))
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
          reducer :: (entry :: Token.t(), accumulator -> accumulator),
          some_time_ago_updated :: integer(),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_cataloged_tokens(initial, reducer, some_time_ago_updated \\ 2880, limited? \\ false)
      when is_function(reducer, 2) do
    some_time_ago_updated
    |> Token.cataloged_tokens()
    |> Chain.add_fetcher_limit(limited?)
    |> order_by(asc_nulls_first: :metadata_updated_at)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Update a new `t:Token.t/0` record.

  As part of updating token, an additional record is inserted for
  naming the address for reference if a name is provided for a token.
  """
  @spec update(Token.t(), map(), boolean(), :base | :metadata_update) :: {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  def update(
        %Token{contract_address_hash: address_hash} = token,
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
      |> Token.changeset(
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
        ]) :: [Token.t()]
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
      |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash, options)
      |> apply_filter(token_type)
      |> SortingHelper.apply_sorting(sorting, @default_sorting)
      |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)

    filtered_query =
      case filter && filter !== "" && Search.prepare_search_term(filter) do
        {:some, filter_term} ->
          sorted_paginated_query
          |> where(fragment("to_tsvector('english', symbol || ' ' || name) @@ to_tsquery(?)", ^filter_term))

        _ ->
          sorted_paginated_query
      end

    filtered_query
    |> Chain.select_repo(options).all()
  end

  defp apply_filter(query, empty_type) when empty_type in [nil, []], do: query

  defp apply_filter(query, token_types) when is_list(token_types) do
    from(t in query, where: t.type in ^token_types)
  end

  def get_by_contract_address_hash(hash, options) do
    Chain.select_repo(options).get_by(__MODULE__, contract_address_hash: hash)
  end

  @doc """
    Gets tokens with given contract address hashes.
  """
  @spec get_by_contract_address_hashes([Hash.Address.t()], [Chain.api?()]) :: [Token.t()]
  def get_by_contract_address_hashes(hashes, options) do
    Chain.select_repo(options).all(from(t in __MODULE__, where: t.contract_address_hash in ^hashes))
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
  def update_token_holder_count(contract_address_hash, holder_count) when not is_nil(holder_count) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(t in __MODULE__,
        where: t.contract_address_hash == ^contract_address_hash,
        update: [set: [holder_count: ^holder_count, updated_at: ^now]]
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
end
