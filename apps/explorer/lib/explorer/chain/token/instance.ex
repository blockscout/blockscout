defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC-721/ERC-1155/ERC-404 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.{Address, Hash, Token, TokenTransfer}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Token.Instance
  alias Explorer.PagingOptions

  @timeout 60_000

  @typedoc """
  * `token_id` - ID of the token
  * `token_contract_address_hash` - Address hash foreign key
  * `metadata` - Token instance metadata
  * `error` - error fetching token instance
  * `refetch_after` - when to refetch the token instance
  * `retries_count` - number of times the token instance has been retried
  * `is_banned` - if the token instance is banned
  """
  @primary_key false
  typed_schema "token_instances" do
    field(:token_id, :decimal, primary_key: true, null: false)
    field(:metadata, :map)
    field(:error, :string)
    field(:owner_updated_at_block, :integer)
    field(:owner_updated_at_log_index, :integer)
    field(:current_token_balance, :any, virtual: true)
    field(:is_unique, :boolean, virtual: true)
    field(:refetch_after, :utc_datetime_usec)
    field(:retries_count, :integer)
    field(:is_banned, :boolean, default: false)

    belongs_to(:owner, Address, foreign_key: :owner_address_hash, references: :hash, type: Hash.Address)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      type: Hash.Address,
      primary_key: true,
      null: false
    )

    timestamps()
  end

  def changeset(%Instance{} = instance, params \\ %{}) do
    instance
    |> cast(params, [
      :token_id,
      :metadata,
      :token_contract_address_hash,
      :error,
      :owner_address_hash,
      :owner_updated_at_block,
      :owner_updated_at_log_index,
      :refetch_after,
      :retries_count,
      :is_banned
    ])
    |> validate_required([:token_id, :token_contract_address_hash])
    |> foreign_key_constraint(:token_contract_address_hash)
  end

  @doc """
  Inventory tab query.
  A token ERC-721 is considered unique because it corresponds to the possession
  of a specific asset.

  To find out its current owner, it is necessary to look at the token last
  transfer.
  """

  def address_to_unique_token_instances(contract_address_hash) do
    from(
      i in Instance,
      where: i.token_contract_address_hash == ^contract_address_hash,
      order_by: [desc: i.token_id]
    )
  end

  def page_token_instance(query, %PagingOptions{key: {token_id}, asc_order: true}) do
    where(query, [i], i.token_id > ^token_id)
  end

  def page_token_instance(query, %PagingOptions{key: {token_id}}) do
    where(query, [i], i.token_id < ^token_id)
  end

  def page_token_instance(query, _), do: query

  def owner_query(%Instance{token_contract_address_hash: token_contract_address_hash, token_id: token_id}) do
    CurrentTokenBalance
    |> where(
      [ctb],
      ctb.token_contract_address_hash == ^token_contract_address_hash and ctb.token_id == ^token_id and ctb.value > 0
    )
    |> limit(1)
    |> select([ctb], ctb.address_hash)
  end

  @spec token_instance_query(Decimal.t() | non_neg_integer(), Hash.Address.t()) :: Ecto.Query.t()
  def token_instance_query(token_id, token_contract_address),
    do: from(i in Instance, where: i.token_contract_address_hash == ^token_contract_address and i.token_id == ^token_id)

  @spec nft_list(binary() | Hash.Address.t(), keyword()) :: [Instance.t()]
  def nft_list(address_hash, options \\ [])

  def nft_list(address_hash, options) when is_list(options) do
    nft_list(address_hash, Keyword.get(options, :token_type, []), options)
  end

  defp nft_list(address_hash, ["ERC-721"], options) do
    erc_721_token_instances_by_owner_address_hash(address_hash, options)
  end

  defp nft_list(address_hash, ["ERC-1155"], options) do
    erc_1155_token_instances_by_address_hash(address_hash, options)
  end

  defp nft_list(address_hash, ["ERC-404"], options) do
    erc_404_token_instances_by_address_hash(address_hash, options)
  end

  defp nft_list(address_hash, _, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {_contract_address_hash, _token_id, "ERC-1155"}} ->
        erc_1155_token_instances_by_address_hash(address_hash, options)

      %PagingOptions{key: {_contract_address_hash, _token_id, "ERC-404"}} ->
        erc_404_token_instances_by_address_hash(address_hash, options)

      _ ->
        erc_721 = erc_721_token_instances_by_owner_address_hash(address_hash, options)

        if length(erc_721) == paging_options.page_size do
          erc_721
        else
          erc_1155 = erc_1155_token_instances_by_address_hash(address_hash, options)
          erc_404 = erc_404_token_instances_by_address_hash(address_hash, options)

          (erc_721 ++ erc_1155 ++ erc_404) |> Enum.take(paging_options.page_size)
        end
    end
  end

  @doc """
    In this function used fact that only ERC-721 instances has NOT NULL owner_address_hash.
  """
  @spec erc_721_token_instances_by_owner_address_hash(binary() | Hash.Address.t(), keyword) :: [Instance.t()]
  def erc_721_token_instances_by_owner_address_hash(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

        __MODULE__
        |> where([ti], ti.owner_address_hash == ^address_hash)
        |> order_by([ti], asc: ti.token_contract_address_hash, desc: ti.token_id)
        |> limit(^paging_options.page_size)
        |> page_erc_721_token_instances(paging_options)
        |> Chain.join_associations(necessity_by_association)
        |> Chain.select_repo(options).all()
    end
  end

  defp page_erc_721_token_instances(query, %PagingOptions{key: {contract_address_hash, token_id, "ERC-721"}}) do
    page_token_instance(query, contract_address_hash, token_id)
  end

  defp page_erc_721_token_instances(query, _), do: query

  @spec erc_1155_token_instances_by_address_hash(binary() | Hash.Address.t(), keyword) :: [Instance.t()]
  def erc_1155_token_instances_by_address_hash(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

        __MODULE__
        |> join(:inner, [ti], ctb in CurrentTokenBalance,
          as: :ctb,
          on:
            ctb.token_contract_address_hash == ti.token_contract_address_hash and ctb.token_id == ti.token_id and
              ctb.address_hash == ^address_hash
        )
        |> where([ctb: ctb], ctb.value > 0 and ctb.token_type == "ERC-1155")
        |> order_by([ti], asc: ti.token_contract_address_hash, desc: ti.token_id)
        |> limit(^paging_options.page_size)
        |> page_erc_1155_token_instances(paging_options)
        |> select_merge([ctb: ctb], %{current_token_balance: ctb})
        |> Chain.join_associations(necessity_by_association)
        |> Chain.select_repo(options).all()
    end
  end

  defp page_erc_1155_token_instances(query, %PagingOptions{key: {contract_address_hash, token_id, "ERC-1155"}}) do
    page_token_instance(query, contract_address_hash, token_id)
  end

  defp page_erc_1155_token_instances(query, _), do: query

  @spec erc_404_token_instances_by_address_hash(binary() | Hash.Address.t(), keyword) :: [Instance.t()]
  def erc_404_token_instances_by_address_hash(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

        __MODULE__
        |> join(:inner, [ti], ctb in CurrentTokenBalance,
          as: :ctb,
          on:
            ctb.token_contract_address_hash == ti.token_contract_address_hash and ctb.token_id == ti.token_id and
              ctb.address_hash == ^address_hash
        )
        |> where([ctb: ctb], ctb.value > 0 and ctb.token_type == "ERC-404")
        |> order_by([ti], asc: ti.token_contract_address_hash, desc: ti.token_id)
        |> limit(^paging_options.page_size)
        |> page_erc_404_token_instances(paging_options)
        |> select_merge([ctb: ctb], %{current_token_balance: ctb})
        |> Chain.join_associations(necessity_by_association)
        |> Chain.select_repo(options).all()
    end
  end

  defp page_erc_404_token_instances(query, %PagingOptions{key: {contract_address_hash, token_id, "ERC-404"}}) do
    page_token_instance(query, contract_address_hash, token_id)
  end

  defp page_erc_404_token_instances(query, _), do: query

  defp page_token_instance(query, contract_address_hash, token_id) do
    query
    |> where(
      [ti],
      ti.token_contract_address_hash > ^contract_address_hash or
        (ti.token_contract_address_hash == ^contract_address_hash and ti.token_id < ^token_id)
    )
  end

  @doc """
    Function to be used in BlockScoutWeb.Chain.next_page_params/4
  """
  @spec nft_list_next_page_params(Explorer.Chain.Token.Instance.t()) :: %{binary() => any}
  def nft_list_next_page_params(%__MODULE__{
        current_token_balance: %CurrentTokenBalance{},
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id,
        token: token
      }) do
    %{"token_contract_address_hash" => token_contract_address_hash, "token_id" => token_id, "token_type" => token.type}
  end

  def nft_list_next_page_params(%__MODULE__{
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id
      }) do
    %{"token_contract_address_hash" => token_contract_address_hash, "token_id" => token_id, "token_type" => "ERC-721"}
  end

  @preloaded_nfts_limit 9

  @spec nft_collections(binary() | Hash.Address.t(), keyword) :: list
  def nft_collections(address_hash, options \\ [])

  def nft_collections(address_hash, options) when is_list(options) do
    nft_collections(address_hash, Keyword.get(options, :token_type, []), options)
  end

  defp nft_collections(address_hash, ["ERC-721"], options) do
    erc_721_collections_by_address_hash(address_hash, options)
  end

  defp nft_collections(address_hash, ["ERC-1155"], options) do
    erc_1155_collections_by_address_hash(address_hash, options)
  end

  defp nft_collections(address_hash, ["ERC-404"], options) do
    erc_404_collections_by_address_hash(address_hash, options)
  end

  defp nft_collections(address_hash, _, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {_contract_address_hash, "ERC-1155"}} ->
        erc_1155_collections_by_address_hash(address_hash, options)

      _ ->
        erc_721 = erc_721_collections_by_address_hash(address_hash, options)

        if length(erc_721) == paging_options.page_size do
          erc_721
        else
          erc_1155 = erc_1155_collections_by_address_hash(address_hash, options)
          erc_404 = erc_404_collections_by_address_hash(address_hash, options)

          (erc_721 ++ erc_1155 ++ erc_404) |> Enum.take(paging_options.page_size)
        end
    end
  end

  @spec erc_721_collections_by_address_hash(binary() | Hash.Address.t(), keyword) :: [CurrentTokenBalance.t()]
  def erc_721_collections_by_address_hash(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    CurrentTokenBalance
    |> where([ctb], ctb.address_hash == ^address_hash and ctb.value > 0 and ctb.token_type == "ERC-721")
    |> order_by([ctb], asc: ctb.token_contract_address_hash)
    |> page_erc_721_nft_collections(paging_options)
    |> limit(^paging_options.page_size)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
    |> Enum.map(&erc_721_preload_nft(&1, options))
  end

  defp page_erc_721_nft_collections(query, %PagingOptions{key: {contract_address_hash, "ERC-721"}}) do
    page_nft_collections(query, contract_address_hash)
  end

  defp page_erc_721_nft_collections(query, _), do: query

  @spec erc_1155_collections_by_address_hash(binary() | Hash.Address.t(), keyword) :: [
          %{
            token_contract_address_hash: Hash.Address.t(),
            distinct_token_instances_count: integer(),
            token_ids: [integer()]
          }
        ]
  def erc_1155_collections_by_address_hash(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    CurrentTokenBalance
    |> where([ctb], ctb.address_hash == ^address_hash and ctb.value > 0 and ctb.token_type == "ERC-1155")
    |> group_by([ctb], ctb.token_contract_address_hash)
    |> order_by([ctb], asc: ctb.token_contract_address_hash)
    |> select([ctb], %{
      token_contract_address_hash: ctb.token_contract_address_hash,
      distinct_token_instances_count: fragment("COUNT(*)"),
      token_ids: fragment("array_agg(?)", ctb.token_id)
    })
    |> page_erc_1155_nft_collections(paging_options)
    |> limit(^paging_options.page_size)
    |> Chain.select_repo(options).all()
    |> Enum.map(&erc_1155_preload_nft(&1, address_hash, options))
    |> Helper.custom_preload(options, Token, :token_contract_address_hash, :contract_address_hash, :token)
  end

  defp page_erc_1155_nft_collections(query, %PagingOptions{key: {contract_address_hash, "ERC-1155"}}) do
    page_nft_collections(query, contract_address_hash)
  end

  defp page_erc_1155_nft_collections(query, _), do: query

  @spec erc_404_collections_by_address_hash(binary() | Hash.Address.t(), keyword) :: [
          %{
            token_contract_address_hash: Hash.Address.t(),
            distinct_token_instances_count: integer(),
            token_ids: [integer()]
          }
        ]
  def erc_404_collections_by_address_hash(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    CurrentTokenBalance
    |> where([ctb], ctb.address_hash == ^address_hash and not is_nil(ctb.token_id) and ctb.token_type == "ERC-404")
    |> group_by([ctb], ctb.token_contract_address_hash)
    |> order_by([ctb], asc: ctb.token_contract_address_hash)
    |> select([ctb], %{
      token_contract_address_hash: ctb.token_contract_address_hash,
      distinct_token_instances_count: fragment("COUNT(*)"),
      token_ids: fragment("array_agg(?)", ctb.token_id)
    })
    |> page_erc_404_nft_collections(paging_options)
    |> limit(^paging_options.page_size)
    |> Chain.select_repo(options).all()
    |> Enum.map(&erc_1155_preload_nft(&1, address_hash, options))
    |> Helper.custom_preload(options, Token, :token_contract_address_hash, :contract_address_hash, :token)
  end

  defp page_erc_404_nft_collections(query, %PagingOptions{key: {contract_address_hash, "ERC-404"}}) do
    page_nft_collections(query, contract_address_hash)
  end

  defp page_erc_404_nft_collections(query, _), do: query

  defp page_nft_collections(query, token_contract_address_hash) do
    query
    |> where([ctb], ctb.token_contract_address_hash > ^token_contract_address_hash)
  end

  defp erc_721_preload_nft(
         %CurrentTokenBalance{token_contract_address_hash: token_contract_address_hash, address_hash: address_hash} =
           ctb,
         options
       ) do
    instances =
      Instance
      |> where(
        [ti],
        ti.token_contract_address_hash == ^token_contract_address_hash and ti.owner_address_hash == ^address_hash
      )
      |> order_by([ti], desc: ti.token_id)
      |> limit(^@preloaded_nfts_limit)
      |> Chain.select_repo(options).all()

    %CurrentTokenBalance{ctb | preloaded_token_instances: instances}
  end

  defp erc_1155_preload_nft(
         %{token_contract_address_hash: token_contract_address_hash, token_ids: token_ids} = collection,
         address_hash,
         options
       ) do
    token_ids = token_ids |> Enum.sort(:desc) |> Enum.take(@preloaded_nfts_limit)

    instances =
      Instance
      |> where([ti], ti.token_contract_address_hash == ^token_contract_address_hash and ti.token_id in ^token_ids)
      |> join(:inner, [ti], ctb in CurrentTokenBalance,
        as: :ctb,
        on:
          ctb.token_contract_address_hash == ti.token_contract_address_hash and ti.token_id == ctb.token_id and
            ctb.address_hash == ^address_hash
      )
      |> limit(^@preloaded_nfts_limit)
      |> select_merge([ctb: ctb], %{current_token_balance: ctb})
      |> Chain.select_repo(options).all()
      |> Enum.sort_by(& &1.token_id, :desc)

    Map.put(collection, :preloaded_token_instances, instances)
  end

  @doc """
    Function to be used in BlockScoutWeb.Chain.next_page_params/4
  """
  @spec nft_collections_next_page_params(%{:token_contract_address_hash => any, optional(any) => any}) :: %{
          binary() => any
        }
  def nft_collections_next_page_params(%{
        token_contract_address_hash: token_contract_address_hash,
        token: %Token{type: token_type}
      }) do
    %{"token_contract_address_hash" => token_contract_address_hash, "token_type" => token_type}
  end

  def nft_collections_next_page_params(%{
        token_contract_address_hash: token_contract_address_hash,
        token_type: token_type
      }) do
    %{"token_contract_address_hash" => token_contract_address_hash, "token_type" => token_type}
  end

  @spec token_instances_by_holder_address_hash(Token.t(), binary() | Hash.Address.t(), keyword) :: [Instance.t()]
  def token_instances_by_holder_address_hash(token, holder_address_hash, options \\ [])

  def token_instances_by_holder_address_hash(%Token{type: "ERC-721"} = token, holder_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        token.contract_address_hash
        |> address_to_unique_token_instances()
        |> where([ti], ti.owner_address_hash == ^holder_address_hash)
        |> limit(^paging_options.page_size)
        |> page_token_instance(paging_options)
        |> Chain.select_repo(options).all()
        |> Enum.map(&put_is_unique(&1, token, options))
    end
  end

  def token_instances_by_holder_address_hash(%Token{} = token, holder_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        __MODULE__
        |> where([ti], ti.token_contract_address_hash == ^token.contract_address_hash)
        |> join(:inner, [ti], ctb in CurrentTokenBalance,
          as: :ctb,
          on:
            ctb.token_contract_address_hash == ti.token_contract_address_hash and ctb.token_id == ti.token_id and
              ctb.address_hash == ^holder_address_hash
        )
        |> where([ctb: ctb], ctb.value > 0)
        |> order_by([ti], desc: ti.token_id)
        |> limit(^paging_options.page_size)
        |> page_token_instance(paging_options)
        |> select_merge([ctb: ctb], %{current_token_balance: ctb})
        |> Chain.select_repo(options).all()
        |> Enum.map(&put_is_unique(&1, token, options))
    end
  end

  @doc """
    Finds token instances (pairs of contract_address_hash and token_id) which was met in token transfers but has no corresponding entry in token_instances table
  """
  @spec not_inserted_token_instances_query(integer()) :: Ecto.Query.t()
  def not_inserted_token_instances_query(limit) do
    token_transfers_query =
      TokenTransfer
      |> where([token_transfer], not is_nil(token_transfer.token_ids) and token_transfer.token_ids != ^[])
      |> select([token_transfer], %{
        token_contract_address_hash: token_transfer.token_contract_address_hash,
        token_id: fragment("unnest(?)", token_transfer.token_ids)
      })

    token_transfers_query
    |> subquery()
    |> join(:left, [token_transfer], token_instance in __MODULE__,
      on:
        token_instance.token_contract_address_hash == token_transfer.token_contract_address_hash and
          token_instance.token_id == token_transfer.token_id
    )
    |> where([token_transfer, token_instance], is_nil(token_instance.token_id))
    |> select([token_transfer, token_instance], %{
      contract_address_hash: token_transfer.token_contract_address_hash,
      token_id: token_transfer.token_id
    })
    |> limit(^limit)
  end

  @doc """
    Finds token instances of a particular token (pairs of contract_address_hash and token_id) which was met in token_transfers table but has no corresponding entry in token_instances table.
  """
  @spec not_inserted_token_instances_query_by_token(integer(), Hash.Address.t()) :: Ecto.Query.t()
  def not_inserted_token_instances_query_by_token(limit, token_contract_address_hash) do
    token_transfers_query =
      TokenTransfer
      |> where([token_transfer], token_transfer.token_contract_address_hash == ^token_contract_address_hash)
      |> select([token_transfer], %{
        token_contract_address_hash: token_transfer.token_contract_address_hash,
        token_id: fragment("unnest(?)", token_transfer.token_ids)
      })

    token_transfers_query
    |> subquery()
    |> join(:left, [token_transfer], token_instance in __MODULE__,
      on:
        token_instance.token_contract_address_hash == token_transfer.token_contract_address_hash and
          token_instance.token_id == token_transfer.token_id
    )
    |> where([token_transfer, token_instance], is_nil(token_instance.token_id))
    |> select([token_transfer, token_instance], %{
      contract_address_hash: token_transfer.token_contract_address_hash,
      token_id: token_transfer.token_id
    })
    |> limit(^limit)
  end

  @doc """
    Finds ERC-1155 token instances (pairs of contract_address_hash and token_id) which was met in current_token_balances table but has no corresponding entry in token_instances table.
  """
  @spec not_inserted_erc_1155_token_instances(integer()) :: Ecto.Query.t()
  def not_inserted_erc_1155_token_instances(limit) do
    CurrentTokenBalance
    |> join(:left, [actb], ti in __MODULE__,
      on: actb.token_contract_address_hash == ti.token_contract_address_hash and actb.token_id == ti.token_id
    )
    |> where([actb, ti], not is_nil(actb.token_id) and is_nil(ti.token_id))
    |> select([actb], %{
      contract_address_hash: actb.token_contract_address_hash,
      token_id: actb.token_id
    })
    |> limit(^limit)
  end

  @doc """
    Puts is_unique field in token instance. Returns updated token instance
    is_unique is true for ERC-721 always and for ERC-1155 only if token_id is unique
  """
  @spec put_is_unique(Instance.t(), Token.t(), Keyword.t()) :: Instance.t()
  def put_is_unique(instance, token, options) do
    %__MODULE__{instance | is_unique: unique?(instance, token, options)}
  end

  defp unique?(
         %Instance{current_token_balance: %CurrentTokenBalance{value: %Decimal{} = value}} = instance,
         token,
         options
       ) do
    if Decimal.compare(value, 1) == :gt do
      false
    else
      unique?(%Instance{instance | current_token_balance: nil}, token, options)
    end
  end

  defp unique?(%Instance{current_token_balance: %CurrentTokenBalance{value: value}}, _token, _options)
       when value > 1,
       do: false

  defp unique?(instance, token, options),
    do:
      not (token.type == "ERC-1155") or
        Chain.token_id_1155_is_unique?(token.contract_address_hash, instance.token_id, options)

  @doc """
  Sets set_metadata for the given Explorer.Chain.Token.Instance
  """
  @spec set_metadata(__MODULE__, map()) :: {non_neg_integer(), nil}
  def set_metadata(token_instance, metadata) when is_map(metadata) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(instance in __MODULE__,
        where: instance.token_contract_address_hash == ^token_instance.token_contract_address_hash,
        where: instance.token_id == ^token_instance.token_id
      ),
      [set: [metadata: metadata, error: nil, updated_at: now]],
      timeout: @timeout
    )
  end
end
