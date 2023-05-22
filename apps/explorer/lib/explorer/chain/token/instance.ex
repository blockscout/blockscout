defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC-721/ERC-1155 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Token, TokenTransfer}
  alias Explorer.Chain.Token.Instance
  alias Explorer.PagingOptions

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

  @spec token_instance_query(non_neg_integer(), Hash.Address.t()) :: Ecto.Query.t()
  def token_instance_query(token_id, token_contract_address),
    do: from(i in Instance, where: i.token_contract_address_hash == ^token_contract_address and i.token_id == ^token_id)
end
