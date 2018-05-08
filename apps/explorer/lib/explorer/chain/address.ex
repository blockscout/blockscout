defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Credit, Debit, Hash, Wei}

  @optional_attrs ~w()a
  @required_attrs ~w(hash)a

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
  * `fetched_balance` - The last fetched balance from Parity
  * `balance_fetched_at` - the last time `balance` was fetched
  * `credit` - accumulation of all credits to the address `hash`
  * `debit` - accumulation of all debits to the address `hash`
  * `hash` - the hash of the address's public key
  * `inserted_at` - when this address was inserted
  * `updated_at` when this address was last updated
  """
  @type t :: %__MODULE__{
          fetched_balance: Wei.t(),
          balance_fetched_at: DateTime.t(),
          credit: %Ecto.Association.NotLoaded{} | Credit.t() | nil,
          debit: %Ecto.Association.NotLoaded{} | Debit.t() | nil,
          hash: Hash.Truncated.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:hash, Hash.Truncated, autogenerate: false}
  schema "addresses" do
    field(:fetched_balance, Wei)
    field(:balance_fetched_at, Timex.Ecto.DateTime)

    timestamps()

    has_one(:credit, Credit)
    has_one(:debit, Debit)
  end

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, [:fetched_balance])
    |> validate_required([:fetched_balance])
    |> put_change(:balance_fetched_at, Timex.now())
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  @spec hash_set_to_changes_list(MapSet.t(Hash.Truncated.t())) :: [%{hash: Hash.Truncated.t()}]
  def hash_set_to_changes_list(hash_set) do
    Enum.map(hash_set, &hash_to_changes/1)
  end

  defp hash_to_changes(%Hash{byte_count: 20} = hash) do
    %{hash: hash}
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
