defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Data, Hash, Wei, SmartContract}

  @optional_attrs ~w(contract_code)a
  @required_attrs ~w(hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
   * `fetched_balance` - The last fetched balance from Parity
   * `balance_fetched_at` - the last time `balance` was fetched
   * `hash` - the hash of the address's public key
   * `contract_code` - the code of the contract when an Address is a contract
   * `inserted_at` - when this address was inserted
   * `updated_at` when this address was last updated
  """
  @type t :: %__MODULE__{
          fetched_balance: Wei.t(),
          balance_fetched_at: DateTime.t(),
          hash: Hash.Truncated.t(),
          contract_code: Data.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:hash, Hash.Truncated, autogenerate: false}
  schema "addresses" do
    field(:fetched_balance, Wei)
    field(:balance_fetched_at, :utc_datetime)
    field(:contract_code, Data)

    has_one(:smart_contract, SmartContract)

    timestamps()
  end

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, [:fetched_balance])
    |> validate_required([:fetched_balance])
    |> put_change(:balance_fetched_at, Timex.now())
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
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
