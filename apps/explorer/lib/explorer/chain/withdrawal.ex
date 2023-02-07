defmodule Explorer.Chain.Withdrawal do
  @moduledoc """
  A stored representation of withdrawal introduced in [EIP-4895](https://eips.ethereum.org/EIPS/eip-4895)
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.PagingOptions

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          validator_index: non_neg_integer(),
          amount: Wei.t(),
          block: %Ecto.Association.NotLoaded{} | Block.t(),
          block_hash: Hash.Full.t(),
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t()
        }

  @required_attrs ~w(index validator_index amount address_hash block_hash)a

  @primary_key {:index, :integer, autogenerate: false}
  schema "withdrawals" do
    field(:validator_index, :integer)
    field(:amount, Wei)

    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full
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
    from(withdrawal in __MODULE__,
      select: withdrawal,
      order_by: [desc: :index],
      where: withdrawal.block_hash == ^block_hash
    )
  end

  @spec address_hash_to_withdrawals_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_withdrawals_query(address_hash) do
    from(withdrawal in __MODULE__,
      select: withdrawal,
      left_join: block in assoc(withdrawal, :block),
      order_by: [desc: :index],
      where: withdrawal.address_hash == ^address_hash,
      where: block.consensus
    )
  end

  @spec blocks_without_withdrowals_query(non_neg_integer()) :: Ecto.Query.t()
  def blocks_without_withdrowals_query(from_block) do
    from(withdrawal in __MODULE__,
      right_join: block in assoc(withdrawal, :block),
      select: block.number,
      distinct: block.number,
      where: block.number >= ^from_block,
      where: block.consensus == ^true,
      where: is_nil(withdrawal.index)
    )
  end
end
