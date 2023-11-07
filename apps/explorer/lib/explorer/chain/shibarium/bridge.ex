defmodule Explorer.Chain.Shibarium.Bridge do
  @moduledoc "Models Shibarium Bridge operation."

  use Explorer.Schema

  alias Explorer.Chain.{
    Address,
    Hash,
    Transaction
  }

  @optional_attrs ~w(amount_or_id erc1155_ids erc1155_amounts l1_transaction_hash l1_block_number l2_transaction_hash l2_block_number timestamp)a

  @required_attrs ~w(user operation_hash operation_type token_type)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  * `user_address` - address of the user that initiated operation
  * `user` - foreign key of `user_address`
  * `amount_or_id` - amount of the operation or NTF id (in case of ERC-721 token)
  * `erc1155_ids` - an array of ERC-1155 token ids (when batch ERC-1155 token transfer)
  * `erc1155_amounts` - an array of corresponding ERC-1155 token amounts (when batch ERC-1155 token transfer)
  * `l1_transaction_hash` - transaction hash for L1 side
  * `l1_block_number` - block number of `l1_transaction`
  * `l2_transaction` - transaction hash for L2 side
  * `l2_transaction_hash` - foreign key of `l2_transaction`
  * `l2_block_number` - block number of `l2_transaction`
  * `operation_hash` - keccak256 hash of the operation calculated as follows: ExKeccak.hash_256(user, amount_or_id, erc1155_ids, erc1155_amounts, operation_id)
  * `operation_type` - `deposit` or `withdrawal`
  * `token_type` - `bone` or `eth` or `other`
  * `timestamp` - timestamp of the operation block (L1 block for deposit, L2 block - for withdrawal)
  """
  @type t :: %__MODULE__{
          user_address: %Ecto.Association.NotLoaded{} | Address.t(),
          user: Hash.Address.t(),
          amount_or_id: Decimal.t() | nil,
          erc1155_ids: [non_neg_integer()] | nil,
          erc1155_amounts: [Decimal.t()] | nil,
          l1_transaction_hash: Hash.t() | nil,
          l1_block_number: non_neg_integer() | nil,
          l2_transaction: %Ecto.Association.NotLoaded{} | Transaction.t() | nil,
          l2_transaction_hash: Hash.t() | nil,
          l2_block_number: non_neg_integer() | nil,
          operation_hash: Hash.t(),
          operation_type: String.t(),
          token_type: String.t(),
          timestamp: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key false
  schema "shibarium_bridge" do
    belongs_to(:user_address, Address, foreign_key: :user, references: :hash, type: Hash.Address)
    field(:amount_or_id, :decimal)
    field(:erc1155_ids, {:array, :decimal})
    field(:erc1155_amounts, {:array, :decimal})
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_block_number, :integer)
    belongs_to(:l2_transaction, Transaction, foreign_key: :l2_transaction_hash, references: :hash, type: Hash.Full)
    field(:l2_block_number, :integer)
    field(:operation_hash, Hash.Full, primary_key: true)
    field(:operation_type, Ecto.Enum, values: [:deposit, :withdrawal], primary_key: true)
    field(:token_type, Ecto.Enum, values: [:bone, :eth, :other])
    field(:timestamp, :utc_datetime_usec)

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = module, attrs \\ %{}) do
    module
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:operation_hash)
    |> unique_constraint(:operation_type)
  end
end
