defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC-721/ERC-1155/ERC-404 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Helper, QueryHelper, Repo}
  alias Explorer.Chain.{Address, Hash, Token, TokenTransfer, Transaction}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.Token.Instance.Thumbnails
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.PagingOptions

  @default_page_size 50
  @default_paging_options %PagingOptions{page_size: @default_page_size}
  @type paging_options :: {:paging_options, PagingOptions.t()}
  @timeout 60_000

  @type api? :: {:api?, true | false}

  @marked_to_refetch ":marked_to_refetch"

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
  * `metadata_url` - URL where metadata is fetched from
  * `skip_metadata_url` - bool flag indicating if metadata_url intentionally skipped
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
    field(:metadata_url, :string)
    field(:skip_metadata_url, :boolean)

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

  def changeset(%__MODULE__{} = instance, params \\ %{}) do
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
      :cdn_upload_error,
      :metadata_url,
      :skip_metadata_url
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
  @spec address_to_unique_token_instances_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_to_unique_token_instances_query(contract_address_hash) do
    from(
      i in __MODULE__,
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

  def owner_query(%__MODULE__{token_contract_address_hash: token_contract_address_hash, token_id: token_id}) do
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
    do:
      from(i in __MODULE__, where: i.token_contract_address_hash == ^token_contract_address and i.token_id == ^token_id)

  @spec nft_list(binary() | Hash.Address.t(), keyword()) :: [__MODULE__.t()]
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
  @spec erc_721_token_instances_by_owner_address_hash(binary() | Hash.Address.t(), keyword) :: [__MODULE__.t()]
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
        |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
        |> page_erc_721_token_instances(paging_options)
        |> Chain.join_associations(necessity_by_association)
        |> Chain.select_repo(options).all()
    end
  end

  defp page_erc_721_token_instances(query, %PagingOptions{key: {contract_address_hash, token_id, "ERC-721"}}) do
    page_token_instance(query, contract_address_hash, token_id)
  end

  defp page_erc_721_token_instances(query, _), do: query

  @spec erc_1155_token_instances_by_address_hash(binary() | Hash.Address.t(), keyword) :: [__MODULE__.t()]
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
        |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
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

  @spec erc_404_token_instances_by_address_hash(binary() | Hash.Address.t(), keyword) :: [__MODULE__.t()]
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
        |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
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
  @spec nft_list_next_page_params(__MODULE__.t()) :: %{atom() => any}
  def nft_list_next_page_params(%__MODULE__{
        current_token_balance: %CurrentTokenBalance{},
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id,
        token: token
      }) do
    %{token_contract_address_hash: token_contract_address_hash, token_id: token_id, token_type: token.type}
  end

  def nft_list_next_page_params(%__MODULE__{
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id
      }) do
    %{token_contract_address_hash: token_contract_address_hash, token_id: token_id, token_type: "ERC-721"}
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
    |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
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
    |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
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
    |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
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
      __MODULE__
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
      __MODULE__
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
          atom() => any
        }
  def nft_collections_next_page_params(%{
        token_contract_address_hash: token_contract_address_hash,
        token: %Token{type: token_type}
      }) do
    %{token_contract_address_hash: token_contract_address_hash, token_type: token_type}
  end

  def nft_collections_next_page_params(%{
        token_contract_address_hash: token_contract_address_hash,
        token_type: token_type
      }) do
    %{token_contract_address_hash: token_contract_address_hash, token_type: token_type}
  end

  @spec token_instances_by_holder_address_hash(Token.t(), binary() | Hash.Address.t(), keyword) :: [__MODULE__.t()]
  def token_instances_by_holder_address_hash(token, holder_address_hash, options \\ [])

  def token_instances_by_holder_address_hash(%Token{type: "ERC-721"} = token, holder_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}, asc_order: false} ->
        []

      _ ->
        token.contract_address_hash
        |> address_to_unique_token_instances_query()
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
  @spec put_is_unique(__MODULE__.t(), Token.t(), Keyword.t()) :: __MODULE__.t()
  def put_is_unique(instance, token, options) do
    %__MODULE__{instance | is_unique: unique?(instance, token, options)}
  end

  defp unique?(
         %__MODULE__{current_token_balance: %CurrentTokenBalance{value: %Decimal{} = value}} = instance,
         token,
         options
       ) do
    if Decimal.compare(value, 1) == :gt do
      false
    else
      unique?(%__MODULE__{instance | current_token_balance: nil}, token, options)
    end
  end

  defp unique?(%__MODULE__{current_token_balance: %CurrentTokenBalance{value: value}}, _token, _options)
       when value > 1,
       do: false

  defp unique?(instance, token, options),
    do:
      not (token.type == "ERC-1155") or
        Chain.token_id_1155_is_unique?(token.contract_address_hash, instance.token_id, options)

  @doc """
  Sets metadata for the given Explorer.Chain.Token.Instance
  """
  @spec set_metadata(t(), map()) :: {non_neg_integer(), nil}
  def set_metadata(token_instance, %{metadata: metadata, skip_metadata_url: skip_metadata_url} = result)
      when is_map(metadata) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(instance in __MODULE__,
        where: instance.token_contract_address_hash == ^token_instance.token_contract_address_hash,
        where: instance.token_id == ^token_instance.token_id
      ),
      [
        set: [
          metadata: metadata,
          error: nil,
          updated_at: now,
          thumbnails: nil,
          media_type: nil,
          cdn_upload_error: nil,
          skip_metadata_url: skip_metadata_url,
          metadata_url: result[:metadata_url]
        ]
      ],
      timeout: @timeout
    )
  end

  @max_retries_count_value 32767
  @error_to_ban_interval %{
    9 => [
      "VM execution error",
      "request error: 404",
      "no uri",
      "(-32000)",
      "invalid ",
      "{:max_redirect_overflow, ",
      "{:invalid_redirection, ",
      "nxdomain",
      ":nxdomain",
      "econnrefused",
      ":econnrefused",
      "blacklist"
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

  @spec batch_upsert_cdn_results([map()]) :: [t()]
  def batch_upsert_cdn_results([]), do: []

  def batch_upsert_cdn_results(instances) do
    {_, result} =
      Repo.insert_all(__MODULE__, instances,
        on_conflict: {:replace, [:thumbnails, :media_type, :updated_at, :cdn_upload_error]},
        conflict_target: [:token_id, :token_contract_address_hash],
        returning: true
      )

    result
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
      __MODULE__
      |> where(
        [nft],
        ^QueryHelper.tuple_in([:token_id, :token_contract_address_hash], token_instances_id)
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
      from(token_instance in __MODULE__,
        where: ^QueryHelper.tuple_in([:token_id, :token_contract_address_hash], token_instance_ids)
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

  @doc """
  Marks an NFT collection to be refetched by setting its metadata to `nil` and error status to `@marked_to_refetch`.

  ## Parameters
    - `token_contract_address_hash` (Hash.Address.t()): The hash of the token contract address.

  ## Returns
    - `{non_neg_integer(), nil}`: A tuple containing the number of updated rows and `nil`.
  """
  @spec mark_nft_collection_to_refetch(Hash.Address.t()) :: {non_neg_integer(), nil}
  def mark_nft_collection_to_refetch(token_contract_address_hash) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(instance in __MODULE__,
        where: instance.token_contract_address_hash == ^token_contract_address_hash
      ),
      [
        set: [
          metadata: nil,
          error: @marked_to_refetch,
          thumbnails: nil,
          media_type: nil,
          cdn_upload_error: nil,
          is_banned: false,
          retries_count: 0,
          refetch_after: nil,
          updated_at: now
        ]
      ],
      timeout: @timeout
    )
  end

  @doc """
    Finds all token instances where metadata never tried to fetch
  """
  @spec stream_token_instances_with_unfetched_metadata(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_token_instances_with_unfetched_metadata(initial, reducer) when is_function(reducer, 2) do
    __MODULE__
    |> where([instance], is_nil(instance.error) and is_nil(instance.metadata))
    |> select([instance], %{
      contract_address_hash: instance.token_contract_address_hash,
      token_id: instance.token_id
    })
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
    Finds all token instances where metadata never tried to fetch
  """
  @spec stream_token_instances_marked_to_refetch(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_token_instances_marked_to_refetch(initial, reducer) when is_function(reducer, 2) do
    __MODULE__
    |> where([instance], instance.error == ^@marked_to_refetch and is_nil(instance.metadata))
    |> select([instance], %{
      contract_address_hash: instance.token_contract_address_hash,
      token_id: instance.token_id
    })
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Checks if a token instance with the given `token_id` and `token_contract_address` has unfetched metadata.

  ## Parameters

    - `token_id`: The ID of the token instance.
    - `token_contract_address`: The contract address of the token instance.
    - `options`: Optional parameters for the query.

  ## Returns

    - `true` if a token instance with the given `token_id` and `token_contract_address` exists and has unfetched metadata.
    - `false` otherwise.
  """
  @spec token_instance_with_unfetched_metadata?(non_neg_integer, Hash.Address.t(), [api?]) :: boolean
  def token_instance_with_unfetched_metadata?(token_id, token_contract_address, options \\ []) do
    __MODULE__
    |> where([instance], is_nil(instance.error) and is_nil(instance.metadata))
    |> where(
      [instance],
      instance.token_id == ^token_id and instance.token_contract_address_hash == ^token_contract_address
    )
    |> Chain.select_repo(options).exists?()
  end

  @doc """
  Streams token instances with errors, applying a reducer function to each instance.

  ## Parameters

    - `initial`: The initial value passed to the reducer function.
    - `reducer`: A function that takes two arguments and returns a new accumulator value.
    - `limited?` (optional): A boolean indicating whether to limit the number of fetched instances. Defaults to `false`.

  ## Details

  The function filters token instances based on the following criteria:
    - The instance is not banned (`is_nil(instance.is_banned) or not instance.is_banned`).
    - The instance has an error (`not is_nil(instance.error)`).
    - The error type is not `:marked_to_refetch`.
    - The `refetch_after` field is either `nil` or in the past.

  The instances are ordered by:
    - `refetch_after` in ascending order.
    - Errors in `high_priority` in descending order.
    - Errors in `negative_priority` in ascending order.

  The function then applies the `reducer` function to each instance, starting with the `initial` value.

  ## Returns

  A stream of token instances with errors, reduced by the `reducer` function.
  """
  @spec stream_token_instances_with_error(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_token_instances_with_error(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    # likely to get valid metadata
    high_priority = ["request error: 429", ":checkout_timeout"]
    # almost impossible to get valid metadata
    negative_priority = ["VM execution error", "no uri", "invalid json"]

    __MODULE__
    |> where([instance], is_nil(instance.is_banned) or not instance.is_banned)
    |> where([instance], not is_nil(instance.error))
    |> where([instance], is_nil(instance.refetch_after) or instance.refetch_after < ^DateTime.utc_now())
    |> select([instance], %{
      contract_address_hash: instance.token_contract_address_hash,
      token_id: instance.token_id
    })
    |> order_by([instance],
      asc: instance.refetch_after,
      desc: instance.error in ^high_priority,
      asc: instance.error in ^negative_priority
    )
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Fetches unique token instances associated with a given contract address.

  ## Parameters

    - `contract_address_hash`: The hash of the contract address to query.
    - `token`: The token to associate with the instances.
    - `options`: Optional keyword list of options.

  ## Options

    - `:paging_options`: A keyword list of paging options. Defaults to `@default_paging_options`.

  ## Returns

    - A list of unique token instances with their owners preloaded.

  ## Examples

      iex> address_to_unique_tokens("0x1234...", %Token{}, paging_options: [page_size: 10])
      [%TokenInstance{}, ...]

  """
  @spec address_to_unique_tokens(Hash.Address.t(), Token.t(), [paging_options | api?]) :: [__MODULE__.t()]
  def address_to_unique_tokens(contract_address_hash, token, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    contract_address_hash
    |> __MODULE__.address_to_unique_token_instances_query()
    |> __MODULE__.page_token_instance(paging_options)
    |> limit(^paging_options.page_size)
    |> preload([_], owner: [:names, :smart_contract, ^Implementation.proxy_implementations_association()])
    |> Chain.select_repo(options).all()
    |> Enum.map(&put_owner_to_token_instance(&1, token, options))
  end

  @doc """
  Fetches an NFT instance based on the given token ID and token contract address.

  ## Parameters

    - `token_id`: The ID of the token.
    - `token_contract_address`: The address of the token contract.
    - `options`: Optional parameters for the query.

  ## Returns

    - `{:ok, token_instance}` if the token instance is found.
    - `{:error, :not_found}` if the token instance is not found.
  """
  @spec nft_instance_by_token_id_and_token_address(
          Decimal.t() | non_neg_integer(),
          Hash.Address.t(),
          [api?]
        ) ::
          {:ok, __MODULE__.t()} | {:error, :not_found}
  def nft_instance_by_token_id_and_token_address(token_id, token_contract_address, options \\ []) do
    query = __MODULE__.token_instance_query(token_id, token_contract_address)

    case Chain.select_repo(options).one(query) do
      nil -> {:error, :not_found}
      token_instance -> {:ok, token_instance}
    end
  end

  @doc """
    Put owner address to unique token instance. If not unique, return original instance.
  """
  @spec put_owner_to_token_instance(__MODULE__.t(), Token.t(), [api?]) :: __MODULE__.t()
  def put_owner_to_token_instance(token_instance, token, options \\ [])

  def put_owner_to_token_instance(%__MODULE__{is_unique: nil} = token_instance, token, options) do
    put_owner_to_token_instance(__MODULE__.put_is_unique(token_instance, token, options), token, options)
  end

  def put_owner_to_token_instance(
        %__MODULE__{owner: nil, is_unique: true} = token_instance,
        %Token{type: type},
        options
      )
      when type in ["ERC-1155", "ERC-404"] do
    owner_address_hash =
      token_instance
      |> __MODULE__.owner_query()
      |> Chain.select_repo(options).one()

    owner =
      Address.get(
        owner_address_hash,
        options
        |> Keyword.merge(
          necessity_by_association: %{
            :names => :optional,
            :smart_contract => :optional,
            Implementation.proxy_implementations_association() => :optional
          }
        )
      )

    %{token_instance | owner: owner, owner_address_hash: owner_address_hash}
  end

  def put_owner_to_token_instance(%__MODULE__{} = token_instance, _token, _options), do: token_instance

  @doc """
    Expects a list of maps with change params. Inserts using on_conflict: `token_instance_metadata_on_conflict/0`
    !!! Supposed to be used ONLY for import of `metadata` or `error`.
  """
  @spec batch_upsert_token_instances([map()]) :: [__MODULE__.t()]
  def batch_upsert_token_instances(params_list) do
    params_to_insert = adjust_insert_params(params_list)

    {_, result} =
      Repo.insert_all(__MODULE__, params_to_insert,
        on_conflict: token_instance_metadata_on_conflict(),
        conflict_target: [:token_id, :token_contract_address_hash],
        returning: true
      )

    result
  end

  defp token_instance_metadata_on_conflict do
    from(
      token_instance in __MODULE__,
      update: [
        set: [
          metadata: fragment("EXCLUDED.metadata"),
          error: fragment("EXCLUDED.error"),
          owner_updated_at_block: token_instance.owner_updated_at_block,
          owner_updated_at_log_index: token_instance.owner_updated_at_log_index,
          owner_address_hash: token_instance.owner_address_hash,
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token_instance.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_instance.updated_at),
          retries_count: token_instance.retries_count + 1,
          refetch_after: fragment("EXCLUDED.refetch_after"),
          is_banned: fragment("EXCLUDED.is_banned"),
          metadata_url: fragment("EXCLUDED.metadata_url"),
          skip_metadata_url: fragment("EXCLUDED.skip_metadata_url")
        ]
      ],
      where: is_nil(token_instance.metadata)
    )
  end
end
