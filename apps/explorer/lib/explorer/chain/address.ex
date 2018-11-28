defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Block, Data, Hash, InternalTransaction, SmartContract, Token, Wei}

  @optional_attrs ~w(contract_code fetched_coin_balance fetched_coin_balance_block_number nonce)a
  @required_attrs ~w(hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
   * `fetched_coin_balance` - The last fetched balance from Parity
   * `fetched_coin_balance_block_number` - the `t:Explorer.Chain.Block.t/0` `t:Explorer.Chain.Block.block_number/0` for
     which `fetched_coin_balance` was fetched
   * `hash` - the hash of the address's public key
   * `contract_code` - the code of the contract when an Address is a contract
   * `names` - names known for the address
   * `inserted_at` - when this address was inserted
   * `updated_at` when this address was last updated
  """
  @type t :: %__MODULE__{
          fetched_coin_balance: Wei.t(),
          fetched_coin_balance_block_number: Block.block_number(),
          hash: Hash.Address.t(),
          contract_code: Data.t() | nil,
          names: %Ecto.Association.NotLoaded{} | [Address.Name.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          nonce: non_neg_integer() | nil
        }

  @primary_key {:hash, Hash.Address, autogenerate: false}
  schema "addresses" do
    field(:fetched_coin_balance, Wei)
    field(:fetched_coin_balance_block_number, :integer)
    field(:contract_code, Data)
    field(:nonce, :integer)

    has_one(:smart_contract, SmartContract)
    has_one(:token, Token, foreign_key: :contract_address_hash)

    has_one(
      :contracts_creation_internal_transaction,
      InternalTransaction,
      foreign_key: :created_contract_address_hash
    )

    has_many(:names, Address.Name, foreign_key: :address_hash)

    timestamps()
  end

  @balance_changeset_required_attrs @required_attrs ++ ~w(fetched_coin_balance fetched_coin_balance_block_number)a

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@balance_changeset_required_attrs)
    |> changeset()
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  defp changeset(%Changeset{data: %__MODULE__{}} = changeset) do
    changeset
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  defimpl String.Chars do
    @doc """
    Uses `hash` as string representation

        iex> address = %Explorer.Chain.Address{
        ...>   hash: %Explorer.Chain.Hash{
        ...>     byte_count: 20,
        ...>     bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
        ...>              165, 101, 32, 167, 106, 179, 223, 65, 91>>
        ...>   }
        ...> }
        iex> to_string(address)
        "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        iex> to_string(address.hash)
        "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        iex> to_string(address) == to_string(address.hash)
        true

    """
    def to_string(%@for{hash: hash}) do
      @protocol.to_string(hash)
    end
  end
end
