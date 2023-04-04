defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC 721 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Token, Token, Token.Instance, TokenTransfer}
  alias Explorer.Chain.Token.Instance
  alias Explorer.PagingOptions

  alias Explorer.Repo

  @typedoc """
  * `token_id` - ID of the token
  * `token_contract_address_hash` - Address hash foreign key
  * `metadata` - Token instance metadata
  * `error` - error fetching token instance
  """

  @type t :: %Instance{
          token_id: non_neg_integer(),
          token_contract_address_hash: Hash.Address.t(),
          metadata: map() | nil,
          error: String.t()
        }

  @primary_key false
  schema "token_instances" do
    field(:token_id, :decimal, primary_key: true)
    field(:metadata, :map)
    field(:error, :string)

    belongs_to(:owner, Address, references: :hash, define_field: false)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      type: Hash.Address,
      primary_key: true
    )

    timestamps()
  end

  def changeset(%Instance{} = instance, params \\ %{}) do
    instance
    |> cast(params, [:token_id, :metadata, :token_contract_address_hash, :error])
    |> validate_required([:token_id, :token_contract_address_hash])
    |> foreign_key_constraint(:token_contract_address_hash)
  end

  def unfetched_erc_721_token_instances_count do
    nft_tokens =
      from(
        token in Token,
        where: token.type == ^"ERC-721",
        select: token.contract_address_hash
      )

    query =
      from(
        token_transfer in TokenTransfer,
        inner_join: token in subquery(nft_tokens),
        on: token.contract_address_hash == token_transfer.token_contract_address_hash,
        left_join: instance in Instance,
        on:
          token_transfer.token_contract_address_hash == instance.token_contract_address_hash and
            token_transfer.token_id == instance.token_id,
        where: is_nil(instance.token_id) and not is_nil(token_transfer.token_id),
        select: %{
          contract_address_hash: token_transfer.token_contract_address_hash,
          token_id: token_transfer.token_id
        }
      )

    distinct_query =
      from(
        q in subquery(query),
        distinct: [q.contract_address_hash, q.token_id]
      )

    count_query =
      from(
        c in subquery(distinct_query),
        select: %{
          count: fragment("COUNT(*)")
        }
      )

    result = Repo.one(count_query, timeout: :infinity)

    case result do
      nil -> 0
      row -> row.count
    end
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
    from(
      tt in TokenTransfer,
      join: to_address in assoc(tt, :to_address),
      where:
        tt.token_contract_address_hash == ^token_contract_address_hash and
          fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^token_id),
      order_by: [desc: tt.block_number],
      limit: 1,
      select: to_address
    )
  end
end
