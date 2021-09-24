defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  require Bitwise

  use Explorer.Schema

  alias Ecto.Changeset

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    DecompiledSmartContract,
    Hash,
    InternalTransaction,
    SmartContract,
    SmartContractAdditionalSource,
    Token,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Cache.NetVersion
  alias Explorer.Tags.AddressTag

  @optional_attrs ~w(contract_code fetched_coin_balance fetched_coin_balance_block_number nonce decompiled verified)a
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
             :decompiled_smart_contracts,
             :token,
             :contracts_creation_internal_transaction,
             :contracts_creation_transaction,
             :names,
             :smart_contract_additional_sources,
             :tags
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :smart_contract,
             :decompiled_smart_contracts,
             :token,
             :contracts_creation_internal_transaction,
             :contracts_creation_transaction,
             :names,
             :smart_contract_additional_sources,
             :tags
           ]}

  @primary_key {:hash, Hash.Address, autogenerate: false}
  schema "addresses" do
    field(:fetched_coin_balance, Wei)
    field(:fetched_coin_balance_block_number, :integer)
    field(:contract_code, Data)
    field(:nonce, :integer)
    field(:decompiled, :boolean, default: false)
    field(:verified, :boolean, default: false)
    field(:has_decompiled_code?, :boolean, virtual: true)
    field(:stale?, :boolean, virtual: true)

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
    has_many(:decompiled_smart_contracts, DecompiledSmartContract, foreign_key: :address_hash)
    has_many(:smart_contract_additional_sources, SmartContractAdditionalSource, foreign_key: :address_hash)
    has_many(:tags, AddressTag, foreign_key: :id)

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
    checksum_formatted =
      case Application.get_env(:explorer, :checksum_function) || :eth do
        :eth -> eth_checksum(hash)
        :rsk -> rsk_checksum(hash)
      end

    if iodata? do
      ["0x" | checksum_formatted]
    else
      to_string(["0x" | checksum_formatted])
    end
  end

  def eth_checksum(hash) do
    string_hash =
      hash
      |> to_string()
      |> String.trim_leading("0x")

    match_byte_stream = stream_every_four_bytes_of_sha256(string_hash)

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
  end

  # https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP60.md
  def rsk_checksum(hash) do
    chain_id = NetVersion.get_version()

    string_hash =
      hash
      |> to_string()
      |> String.trim_leading("0x")

    prefix = "#{chain_id}0x"

    match_byte_stream = stream_every_four_bytes_of_sha256("#{prefix}#{string_hash}")

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
  end

  defp stream_every_four_bytes_of_sha256(value) do
    hash = ExKeccak.hash_256(value)

    hash
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

  @doc """
  Counts all the addresses.
  """
  def count do
    from(
      a in Address,
      select: fragment("COUNT(*)")
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
