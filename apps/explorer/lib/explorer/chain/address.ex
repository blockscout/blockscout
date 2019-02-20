defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  require Bitwise

  use Explorer.Schema

  alias Ecto.Changeset
  alias Explorer.Chain.{Address, Block, Data, Hash, InternalTransaction, SmartContract, Token, Transaction, Wei}

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
   * `contract_code` - the binary code of the contract when an Address is a contract.  The human-readable
     Solidity source code is in `smart_contract` `t:Explorer.Chain.SmartContract.t/0` `contract_source_code` *if* the
    contract has been verified
   * `names` - names known for the address
   * `inserted_at` - when this address was inserted
   * `updated_at` when this address was last updated

   `fetched_coin_balance` and `fetched_coin_balance_block_number` may be updated when a new coin_balance row is fetched.
    They may also be updated when the balance is fetched via the on demand fetcher.
  """
  @type t :: %__MODULE__{
          fetched_coin_balance: Wei.t(),
          fetched_coin_balance_block_number: Block.block_number(),
          hash: Hash.Address.t(),
          contract_code: Data.t() | nil,
          names: %Ecto.Association.NotLoaded{} | [Address.Name.t()],
          contracts_creation_transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          nonce: non_neg_integer() | nil
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :smart_contract,
             :token,
             :contracts_creation_internal_transaction,
             :contracts_creation_transaction,
             :names
           ]}

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

    has_one(
      :contracts_creation_transaction,
      Transaction,
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

  def checksum(address_or_hash, iodata? \\ false)

  def checksum(%__MODULE__{hash: hash}, iodata?) do
    checksum(hash, iodata?)
  end

  def checksum(hash, iodata?) do
    string_hash =
      hash
      |> to_string()
      |> String.trim_leading("0x")

    match_byte_stream = stream_every_four_bytes_of_sha256(string_hash)

    checksum_formatted =
      string_hash
      |> stream_binary()
      |> Stream.zip(match_byte_stream)
      |> Enum.map(fn
        {digit, _} when digit in '0123456789' ->
          digit

        {alpha, 1} ->
          alpha - 32

        {alpha, _} ->
          alpha
      end)

    if iodata? do
      ["0x" | checksum_formatted]
    else
      to_string(["0x" | checksum_formatted])
    end
  end

  defp stream_every_four_bytes_of_sha256(value) do
    :sha3_256
    |> :keccakf1600.hash(value)
    |> stream_binary()
    |> Stream.map(&Bitwise.band(&1, 136))
    |> Stream.flat_map(fn
      136 ->
        [1, 1]

      128 ->
        [1, 0]

      8 ->
        [0, 1]

      _ ->
        [0, 0]
    end)
  end

  defp stream_binary(string) do
    Stream.unfold(string, fn
      <<char::integer, rest::binary>> ->
        {char, rest}

      _ ->
        nil
    end)
  end

  @doc """
  Counts all the addresses where the `fetched_coin_balance` is > 0.
  """
  def count_with_fetched_coin_balance do
    from(
      a in Address,
      select: fragment("COUNT(*)"),
      where: a.fetched_coin_balance > ^0
    )
  end

  defimpl String.Chars do
    @doc """
    Uses `hash` as string representation, formatting it according to the eip-55 specification

    For more information: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md#specification

    To bypass the checksum formatting, use `to_string/1` on the hash itself.

        iex> address = %Explorer.Chain.Address{
        ...>   hash: %Explorer.Chain.Hash{
        ...>     byte_count: 20,
        ...>     bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
        ...>              165, 101, 32, 167, 106, 179, 223, 65, 91>>
        ...>   }
        ...> }
        iex> to_string(address)
        "0x8Bf38d4764929064f2d4d3a56520A76AB3df415b"
        iex> to_string(address.hash)
        "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
    """
    def to_string(%@for{} = address) do
      @for.checksum(address)
    end
  end
end
