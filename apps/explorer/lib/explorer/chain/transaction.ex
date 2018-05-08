defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Block, Gas, Hash, InternalTransaction, Receipt, Wei}

  @optional_attrs ~w(block_hash from_address_hash index to_address_hash)a
  @required_attrs ~w(gas gas_price hash input nonce public_key r s standard_v v value)a

  @typedoc """
  The full public key of the signer of the transaction.
  """
  @type public_key :: String.t()

  @typedoc """
  X coordinate module n in
  [Elliptic Curve Digital Signature Algorithm](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
  (EDCSA)
  """
  @type r :: String.t()

  @typedoc """
  Y coordinate module n in
  [Elliptic Curve Digital Signature Algorithm](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
  (EDCSA)
  """
  @type s :: String.t()

  @typedoc """
  For message signatures, we use a trick called public key recovery. The fact is that if you have the full R point
  (not just its X coordinate) and `t:s/0`, and a message, you can compute for which public key this would be a valid
  signature. What this allows is to 'verify' a message with an address, without needing to know the full key (we just to
  public key recovery on the signature, and then hash the recovered key and compare it with the address).

  However, this means we need the full R coordinates. There can be up to 4 different points with a given
  "X coordinate modulo n". (2 because each X coordinate has two possible Y coordinates, and 2 because r+n may still be a
  valid X coordinate). That number between 0 and 3 is standard_v.

  | `standard_v`  | X      | Y    |
  |---------------|--------|------|
  | `0`           | lower  | even |
  | `1`           | lower  | odd  |
  | `2`           | higher | even |
  | `3`           | higher | odd  |

  **Note: that `2` and `3` are exceedingly rarely, and will in practice only ever be seen in specifically generated
  examples.**
  """
  @type standard_v :: 0..3

  @typedoc """
  `t:standard_v/0` + `27`

  | `v`  | X      | Y    |
  |------|--------|------|
  | `27` | lower  | even |
  | `28` | lower  | odd  |
  | `29` | higher | even |
  | `30` | higher | odd  |

  **Note: that `29` and `30` are exceedingly rarely, and will in practice only ever be seen in specifically generated
  examples.**
  """
  @type v :: 27..30

  @typedoc """
  How much the sender is willing to pay in wei per unit of gas.
  """
  @type wei_per_gas :: non_neg_integer()

  @typedoc """
  * `block` - the block in which this transaction was mined/validated.  `nil` when transaction is pending.
  * `block_hash` - `block` foreign key. `nil` when transaction is pending.
  * `from_address` - the source of `value`
  * `from_address_hash` - foreign key of `from_address`
  * `gas` - Gas provided by the sender
  * `gas_price` - How much the sender is willing to pay for `gas`
  * `hash` - hash of contents of this transaction
  * `index` - index of this transaction in `block`.  `nil` when transaction is pending.
  * `input`- data sent along with the transaction
  * `internal_transactions` - transactions (value transfers) created while executing contract used for this transaction
  * `nonce` - the number of transaction made by the sender prior to this one
  * `public_key` - public key of the signer of the transaction
  * `r` - the R field of the signature. The (r, s) is the normal output of an ECDSA signature, where r is computed as
      the X coordinate of a point R, modulo the curve order n.
  * `s` - The S field of the signature.  The (r, s) is the normal output of an ECDSA signature, where r is computed as
      the X coordinate of a point R, modulo the curve order n.
  * `standard_v` - The standardized V field of the signature
  * `to_address` - sink of `value`
  * `to_address_hash` - `to_address` foreign key
  * `v` - The V field of the signature.
  * `value` - wei transferred from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          block_hash: Hash.t() | nil,
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Truncated.t(),
          gas: Gas.t(),
          gas_price: wei_per_gas,
          hash: Hash.t(),
          index: non_neg_integer() | nil,
          input: String.t(),
          internal_transactions: %Ecto.Association.NotLoaded{} | [InternalTransaction.t()],
          nonce: non_neg_integer(),
          public_key: public_key(),
          r: r(),
          receipt: %Ecto.Association.NotLoaded{} | Receipt.t(),
          s: s(),
          standard_v: standard_v(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_hash: Hash.Truncated.t(),
          v: v(),
          value: Wei.t()
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "transactions" do
    field(:gas, :decimal)
    field(:gas_price, :decimal)
    field(:index, :integer)
    field(:input, :string)
    field(:nonce, :integer)
    field(:public_key, :string)
    field(:r, :string)
    field(:s, :string)
    field(:standard_v, :string)
    field(:v, :string)
    field(:value, :decimal)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full)

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Truncated
    )

    has_many(:internal_transactions, InternalTransaction, foreign_key: :transaction_hash)
    has_one(:receipt, Receipt, foreign_key: :transaction_hash)

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Truncated
    )
  end

  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> validate_collated()
    |> check_constraint(
      :index,
      message: "cannot be set when block_hash is nil and must be set when block_hash is not nil",
      name: :indexed
    )
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:hash)
  end

  def changes_to_address_hash_set(changes) do
    Enum.reduce(~w(from_address_hash to_address_hash)a, MapSet.new(), fn field, acc ->
      case Map.get(changes, field) do
        nil -> acc
        value -> MapSet.put(acc, value)
      end
    end)
  end

  defp validate_collated(%Changeset{} = changeset) do
    case {Changeset.get_field(changeset, :block_hash), Changeset.get_field(changeset, :index)} do
      {nil, nil} ->
        changeset

      {_block_hash, nil} ->
        Changeset.add_error(changeset, :index, "can't be blank when transaction is collated into a block")

      {nil, _index} ->
        Changeset.add_error(changeset, :index, "can't be set when the transaction is pending")

      _ ->
        changeset
    end
  end
end
