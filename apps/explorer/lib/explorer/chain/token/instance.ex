defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC-721/ERC-1155/ERC-404 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.{Address, Hash, Token, TokenTransfer, Transaction}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Token.Instance
  alias Explorer.Chain.Token.Instance.Thumbnails
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
  * `thumbnails` - info for deriving thumbnails urls. Stored as array: [file_path, sizes, original_uploaded?]
  * `media_type` - mime type of media
  * `cdn_upload_error` - error while processing(resizing)/uploading media to CDN
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
    field(:thumbnails, Thumbnails)
    field(:media_type, :string)
    field(:cdn_upload_error, :string)

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
      :is_banned,
      :thumbnails,
      :media_type,
      :cdn_upload_error
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
      token_contract_address_hash: token_transfer.token_contract_address_hash,
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
      token_contract_address_hash: actb.token_contract_address_hash,
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
  @spec set_metadata(t(), map()) :: {non_neg_integer(), nil}
  def set_metadata(token_instance, metadata) when is_map(metadata) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(instance in __MODULE__,
        where: instance.token_contract_address_hash == ^token_instance.token_contract_address_hash,
        where: instance.token_id == ^token_instance.token_id
      ),
      [set: [metadata: metadata, error: nil, updated_at: now, thumbnails: nil, media_type: nil, cdn_upload_error: nil]],
      timeout: @timeout
    )
  end

  @max_retries_count_value 32767
  @error_to_ban_interval %{
    9 => [
      "VM execution error",
      "request error: 404",
      "no uri",
      "ignored host",
      "(-32000)",
      "invalid ",
      "{:max_redirect_overflow, ",
      "{:invalid_redirection, ",
      "nxdomain",
      ":nxdomain",
      "econnrefused",
      ":econnrefused"
    ],
    # 32767 is the maximum value for retries_count (smallint)
    @max_retries_count_value => ["request error: 429"]
  }

  @doc """
  Determines the maximum number of retries allowed before banning based on the given error.

  ## Parameters
  - error: The error encountered that may trigger retries.

  ## Returns
  - An integer representing the maximum number of retries allowed before a ban is enforced.
  """
  @spec error_to_max_retries_count_before_ban(String.t() | nil) :: non_neg_integer()
  def error_to_max_retries_count_before_ban(nil) do
    @max_retries_count_value
  end

  def error_to_max_retries_count_before_ban(error) do
    Enum.find_value(@error_to_ban_interval, fn {interval, errors} ->
      Enum.any?(errors, fn error_pattern ->
        String.starts_with?(error, error_pattern)
      end) && interval
    end) || 13
  end

  @doc """
  Retrieves the media URL from the given NFT metadata.

  ## Parameters

    - metadata: A map containing the metadata of the NFT.

  ## Returns

    - The media URL as a string if found in the metadata, otherwise `nil`.

  ## Examples

      iex> metadata = %{"image" => "https://example.com/image.png"}
      iex> get_media_url_from_metadata_for_nft_media_handler(metadata)
      "https://example.com/image.png"

      iex> metadata = %{"animation_url" => "https://example.com/animation.mp4"}
      iex> get_media_url_from_metadata_for_nft_media_handler(metadata)
      "https://example.com/animation.mp4"

      iex> metadata = %{}
      iex> get_media_url_from_metadata_for_nft_media_handler(metadata)
      nil
  """
  @spec get_media_url_from_metadata_for_nft_media_handler(nil | map()) :: nil | binary()
  def get_media_url_from_metadata_for_nft_media_handler(metadata) when is_map(metadata) do
    result =
      cond do
        is_binary(metadata["image_url"]) ->
          metadata["image_url"]

        is_binary(metadata["image"]) ->
          metadata["image"]

        is_map(metadata["properties"]) && is_binary(metadata["properties"]["image"]) ->
          metadata["properties"]["image"]

        is_binary(metadata["animation_url"]) ->
          metadata["animation_url"]

        true ->
          nil
      end

    if result && String.trim(result) == "", do: nil, else: result
  end

  def get_media_url_from_metadata_for_nft_media_handler(nil), do: nil

  @doc """
  Sets the media URLs for a given token.

  ## Parameters

    - `token_contract_address_hash`: The hash of the token contract address.
    - `token_id`: The ID of the token.
    - `urls`: list of Explorer.Chain.Token.Instance.Thumbnails format
    - `media_type`: The type of media associated with the URLs.

  ## Examples

      iex> set_media_urls({"0x1234", 1}, ["/folder_1/0004dfda159ea2def5098bf8f19f5f27207f4e1f_{}.png", [60, 250, 500], true], {"image", "png"})
      :ok

  """
  @spec set_media_urls({Hash.Address.t(), non_neg_integer() | Decimal.t()}, list(), {binary(), binary()}) ::
          any()
  def set_media_urls({token_contract_address_hash, token_id}, urls, media_type) do
    now = DateTime.utc_now()

    token_id
    |> token_instance_query(token_contract_address_hash)
    |> Repo.update_all(
      [set: [thumbnails: urls, media_type: media_type_to_string(media_type), updated_at: now]],
      timeout: @timeout
    )
  end

  @doc """
  Sets the CDN upload error for a given token.

  ## Parameters

    - `token_contract_address_hash`: The hash of the token contract address.
    - `token_id`: The ID of the token.
    - `error`: The error message to be set.

  ## Examples

      iex> set_cdn_upload_error({"0x1234", 1}, "Upload failed")
      :ok

  """
  @spec set_cdn_upload_error({Hash.Address.t(), non_neg_integer() | Decimal.t()}, binary()) :: any()
  def set_cdn_upload_error({token_contract_address_hash, token_id}, error) do
    now = DateTime.utc_now()

    token_id
    |> token_instance_query(token_contract_address_hash)
    |> Repo.update_all(
      [set: [cdn_upload_error: error, updated_at: now]],
      timeout: @timeout
    )
  end

  @doc """
  Streams instances that need to be resized and uploaded.

  ## Parameters

    - each_fun: A function to be applied to each instance.
  """
  @spec stream_instances_to_resize_and_upload((t() -> any())) :: any()
  def stream_instances_to_resize_and_upload(each_fun) do
    __MODULE__
    |> where([ti], not is_nil(ti.metadata) and is_nil(ti.thumbnails) and is_nil(ti.cdn_upload_error))
    |> Repo.stream_each(each_fun)
  end

  @doc """
  Sets the CDN result for a given token.

  ## Parameters

    - `token_contract_address_hash`: The hash of the token contract address.
    - `token_id`: The ID of the token.
    - `params`: A map containing the parameters for the CDN result.

  ## Returns

    - The result of setting the CDN for the given token instance.

  """
  @spec set_cdn_result({Hash.Address.t(), non_neg_integer() | Decimal.t()}, %{
          :cdn_upload_error => any(),
          :media_type => any(),
          :thumbnails => any()
        }) :: any()
  def set_cdn_result({token_contract_address_hash, token_id}, %{
        thumbnails: thumbnails,
        media_type: media_type,
        cdn_upload_error: cdn_upload_error
      }) do
    now = DateTime.utc_now()

    token_id
    |> token_instance_query(token_contract_address_hash)
    |> Repo.update_all(
      [
        set: [
          cdn_upload_error: cdn_upload_error,
          thumbnails: thumbnails,
          media_type: media_type,
          updated_at: now
        ]
      ],
      timeout: @timeout
    )
  end

  @doc """
  Converts a media type tuple to a string.

  ## Parameters
  - media_type: A tuple containing two binaries representing the media type.

  ## Returns
  - A non-empty binary string representation of the media type.

  ## Examples
    iex> media_type_to_string({"image", "png"})
    "image/png"
  """
  @spec media_type_to_string({binary(), binary()}) :: nonempty_binary()
  def media_type_to_string({type, subtype}) do
    "#{type}/#{subtype}"
  end

  @doc """
  Preloads NFTs for a list of `TokenTransfer` structs.

  ## Parameters

    - `token_transfers`: A list of `TokenTransfer` structs.
    - `opts`: A keyword list of options.

  ## Returns

  A list of `TokenTransfer` structs with preloaded NFTs.
  """
  @spec preload_nft([TokenTransfer.t()] | Transaction.t(), keyword()) :: [TokenTransfer.t()] | Transaction.t()
  def preload_nft(token_transfers, options) when is_list(token_transfers) do
    token_instances_id =
      token_transfers
      |> Enum.reduce(MapSet.new(), fn
        %TokenTransfer{token_type: nft_token_type} = token_transfer, ids
        when nft_token_type in ["ERC-721", "ERC-1155", "ERC-404"] ->
          MapSet.put(ids, {List.first(token_transfer.token_ids), token_transfer.token_contract_address_hash.bytes})

        _token_transfer, ids ->
          ids
      end)
      |> MapSet.to_list()

    token_instances =
      Instance
      |> where(
        [nft],
        fragment(
          "(?, ?) = ANY(?::token_instance_id[])",
          nft.token_id,
          nft.token_contract_address_hash,
          ^token_instances_id
        )
      )
      |> Chain.select_repo(options).all()
      |> Enum.reduce(%{}, fn nft, map ->
        Map.put(map, {nft.token_id, nft.token_contract_address_hash}, nft)
      end)

    Enum.map(token_transfers, fn
      %TokenTransfer{token_type: nft_token_type} = token_transfer
      when nft_token_type in ["ERC-721", "ERC-1155", "ERC-404"] ->
        %TokenTransfer{
          token_transfer
          | token_instance:
              token_instances[{List.first(token_transfer.token_ids), token_transfer.token_contract_address_hash}]
        }

      token_transfer ->
        token_transfer
    end)
  end

  def preload_nft(%Transaction{token_transfers: token_transfers} = transaction, options)
      when is_list(token_transfers) do
    %Transaction{transaction | token_transfers: preload_nft(token_transfers, options)}
  end

  def preload_nft(other, _options), do: other

  @doc """
  Prepares params list for batch upsert
  (filters out params for instances that shouldn't be updated
  and adjusts `refetch_after` and `is_banned` fields based on existing instances).
  """
  @spec adjust_insert_params([map()]) :: [map()]
  def adjust_insert_params(params_list) do
    now = Timex.now()

    adjusted_params_list =
      Enum.map(params_list, fn params ->
        {:ok, token_contract_address_hash} = Hash.Address.cast(params.token_contract_address_hash)

        Map.merge(params, %{
          token_id: Decimal.new(params.token_id),
          token_contract_address_hash: token_contract_address_hash,
          inserted_at: now,
          updated_at: now
        })
      end)

    token_instance_ids =
      Enum.map(adjusted_params_list, fn params ->
        {params.token_id, params.token_contract_address_hash.bytes}
      end)

    existing_token_instances_query =
      from(token_instance in Instance,
        where:
          fragment(
            "(?, ?) = ANY(?::token_instance_id[])",
            token_instance.token_id,
            token_instance.token_contract_address_hash,
            ^token_instance_ids
          )
      )

    existing_token_instances_map =
      existing_token_instances_query
      |> Repo.all()
      |> Map.new(&{{&1.token_id, &1.token_contract_address_hash}, &1})

    Enum.reduce(adjusted_params_list, [], fn params, acc ->
      existing_token_instance =
        existing_token_instances_map[{params.token_id, params.token_contract_address_hash}]

      cond do
        is_nil(existing_token_instance) ->
          [params | acc]

        is_nil(existing_token_instance.metadata) ->
          {refetch_after, is_banned} = determine_refetch_after_and_is_banned(params, existing_token_instance)
          full_params = Map.merge(params, %{refetch_after: refetch_after, is_banned: is_banned})
          [full_params | acc]

        true ->
          acc
      end
    end)
  end

  defp determine_refetch_after_and_is_banned(params, existing_token_instance) do
    config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)

    coef = config[:exp_timeout_coeff]
    base = config[:exp_timeout_base]
    max_refetch_interval = config[:max_refetch_interval]
    max_retry_count = :math.log(max_refetch_interval / 1000 / coef) / :math.log(base)
    new_retries_count = existing_token_instance.retries_count + 1
    max_retries_count_before_ban = error_to_max_retries_count_before_ban(params[:error])

    cond do
      new_retries_count > max_retries_count_before_ban ->
        {nil, true}

      is_nil(params[:metadata]) ->
        value = floor(coef * :math.pow(base, min(new_retries_count, max_retry_count)))

        {Timex.shift(Timex.now(), seconds: value), false}

      true ->
        {nil, false}
    end
  end
end
