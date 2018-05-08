defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, BlockTransaction, Hash, InternalTransaction, Receipt, Wei}

  # Constants

  @required_attrs ~w(hash value gas gas_price input nonce public_key r s
    standard_v transaction_index v)a

  @optional_attrs ~w(to_address_id from_address_id)a

  # Types

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
  @type wei_per_gas :: Wei.t()

  @typedoc """
  * `block_transaction` - joins this transaction to its `block`
  * `block` - the block in which this transaction was mined/validated
  * `from_address` - the source of `value`
  * `from_address_id` - foreign key of `from_address`
  * `gas` - Gas provided by the sender
  * `gas_price` - How much the sender is willing to pay for `gas`
  * `hash` - hash of contents of this transaction
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
  * `to_address_id` - `to_address` foreign key
  * `transaction_index` - index of this transaction in `block`
  * `v` - The V field of the signature.
  * `value` - wei transferred from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          block: %Ecto.Association.NotLoaded{} | Block.t(),
          block_transaction: %Ecto.Association.NotLoaded{} | BlockTransaction.t(),
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_id: non_neg_integer(),
          gas: Gas.t(),
          gas_price: wei_per_gas,
          hash: Hash.t(),
          input: String.t(),
          internal_transactions: %Ecto.Association.NotLoaded{} | [InternalTransaction.t()],
          nonce: non_neg_integer(),
          public_key: public_key(),
          r: r(),
          receipt: %Ecto.Association.NotLoaded{} | Receipt.t(),
          s: s(),
          standard_v: standard_v(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_id: non_neg_integer(),
          transaction_index: non_neg_integer(),
          v: v(),
          value: Wei.t()
        }

  # Schema

  schema "transactions" do
    field(:gas, :decimal)
    field(:gas_price, Wei)
    field(:hash, :string)
    field(:input, :string)
    field(:nonce, :integer)
    field(:public_key, :string)
    field(:r, :string)
    field(:s, :string)
    field(:standard_v, :string)
    field(:transaction_index, :string)
    field(:v, :string)
    field(:value, Wei)

    timestamps()

    has_one(:block_transaction, BlockTransaction)
    has_one(:block, through: [:block_transaction, :block])
    belongs_to(:from_address, Address)
    has_many(:internal_transactions, InternalTransaction)
    has_one(:receipt, Receipt)
    belongs_to(:to_address, Address)
  end

  @doc false
  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_id)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end

  def null, do: %__MODULE__{}
end
