defmodule Explorer.Chain.Withdrawal do
  @moduledoc """
  A stored representation of withdrawal introduced in [EIP-4895](https://eips.ethereum.org/EIPS/eip-4895)
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.PagingOptions

  @required_attrs ~w(index validator_index amount address_hash block_hash)a

  @primary_key false
  typed_schema "withdrawals" do
    field(:index, :integer, primary_key: true, null: false)
    field(:validator_index, :integer, null: false)
    field(:amount, Wei, null: false)

    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @spec changeset(
          Explorer.Chain.Withdrawal.t(),
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = withdrawal, attrs \\ %{}) do
    withdrawal
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:index, name: :withdrawals_pkey)
  end

  @spec page_withdrawals(Ecto.Query.t(), PagingOptions.t()) :: Ecto.Query.t()
  def page_withdrawals(query, %PagingOptions{key: nil}), do: query

  def page_withdrawals(query, %PagingOptions{key: {index}}) do
    where(query, [withdrawal], withdrawal.index < ^index)
  end

  @spec block_hash_to_withdrawals_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_withdrawals_query(block_hash) do
    block_hash
    |> block_hash_to_withdrawals_unordered_query()
    |> order_by(desc: :index)
  end

  @spec block_hash_to_withdrawals_unordered_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_withdrawals_unordered_query(block_hash) do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      where: withdrawal.block_hash == ^block_hash
    )
  end

  @spec address_hash_to_withdrawals_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_query(address_hash) do
    address_hash
    |> address_hash_to_withdrawals_unordered_query()
    |> order_by(desc: :index)
  end

  @spec address_hash_to_withdrawals_unordered_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_unordered_query(address_hash) do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      left_join: block in assoc(withdrawal, :block),
      where: withdrawal.address_hash == ^address_hash,
      where: block.consensus == true,
      preload: [block: block]
    )
  end

  @spec blocks_without_withdrawals_query(non_neg_integer()) :: Ecto.Query.t()
  def blocks_without_withdrawals_query(from_block) do
    from(withdrawal in __MODULE__,
      right_join: block in assoc(withdrawal, :block),
      select: block.number,
      distinct: block.number,
      where: block.number >= ^from_block,
      where: block.consensus == ^true,
      where: is_nil(withdrawal.index)
    )
  end

  @spec list_withdrawals :: Ecto.Query.t()
  def list_withdrawals do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      order_by: [desc: :index]
    )
  end
end
