defmodule Explorer.Chain.Address do
  @moduledoc """
  A stored representation of a web3 address.
  """

  require Bitwise

  use Explorer.Schema

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Explorer.{Chain, PagingOptions, Repo}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    DecompiledSmartContract,
    Hash,
    InternalTransaction,
    SmartContract,
    Token,
    Transaction,
    Wei,
    Withdrawal
  }

  alias Explorer.Chain.Cache.{Accounts, NetVersion}
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  @optional_attrs ~w(contract_code fetched_coin_balance fetched_coin_balance_block_number nonce decompiled verified gas_used transactions_count token_transfers_count)a
  @required_attrs ~w(hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :smart_contract,
             :decompiled_smart_contracts,
             :token,
             :contracts_creation_internal_transaction,
             :contracts_creation_transaction,
             :names
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :smart_contract,
             :decompiled_smart_contracts,
             :token,
             :contracts_creation_internal_transaction,
             :contracts_creation_transaction,
             :names
           ]}

  @timeout :timer.minutes(1)

  @typedoc """
   * `fetched_coin_balance` - The last fetched balance from Nethermind
   * `fetched_coin_balance_block_number` - the `t:Explorer.Chain.Block.t/0` `t:Explorer.Chain.Block.block_number/0` for
     which `fetched_coin_balance` was fetched
   * `hash` - the hash of the address's public key
   * `contract_code` - the binary code of the contract when an Address is a contract.  The human-readable
     Solidity source code is in `smart_contract` `t:Explorer.Chain.SmartContract.t/0` `contract_source_code` *if* the
    contract has been verified
   * `names` - names known for the address
   * `inserted_at` - when this address was inserted
   * `updated_at` - when this address was last updated
   * `ens_domain_name` - virtual field for ENS domain name passing

   `fetched_coin_balance` and `fetched_coin_balance_block_number` may be updated when a new coin_balance row is fetched.
    They may also be updated when the balance is fetched via the on demand fetcher.
  """
  @primary_key false
  typed_schema "addresses" do
    field(:hash, Hash.Address, primary_key: true)
    field(:fetched_coin_balance, Wei)
    field(:fetched_coin_balance_block_number, :integer) :: Block.block_number() | nil
    field(:contract_code, Data)
    field(:nonce, :integer)
    field(:decompiled, :boolean, default: false)
    field(:verified, :boolean, default: false)
    field(:has_decompiled_code?, :boolean, virtual: true)
    field(:stale?, :boolean, virtual: true)
    field(:transactions_count, :integer)
    field(:token_transfers_count, :integer)
    field(:gas_used, :integer)
    field(:ens_domain_name, :string, virtual: true)
    field(:metadata, :any, virtual: true)
    field(:implementation, :any, virtual: true)

    has_one(:smart_contract, SmartContract, references: :hash)
    has_one(:token, Token, foreign_key: :contract_address_hash, references: :hash)
    has_one(:proxy_implementations, Implementation, foreign_key: :proxy_address_hash, references: :hash)

    has_one(
      :contracts_creation_internal_transaction,
      InternalTransaction,
      foreign_key: :created_contract_address_hash,
      references: :hash
    )

    has_one(
      :contracts_creation_transaction,
      Transaction,
      foreign_key: :created_contract_address_hash,
      references: :hash
    )

    has_many(:names, Address.Name, foreign_key: :address_hash, references: :hash)
    has_many(:decompiled_smart_contracts, DecompiledSmartContract, foreign_key: :address_hash, references: :hash)
    has_many(:withdrawals, Withdrawal, foreign_key: :address_hash, references: :hash)

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

  @spec get(Hash.Address.t(), [Chain.necessity_by_association_option() | Chain.api?()]) :: t() | nil
  def get(hash, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query = from(address in Address, where: address.hash == ^hash)

    query
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).one()
  end

  def checksum(address_or_hash, iodata? \\ false)

  def checksum(nil, _iodata?), do: ""

  def checksum(%__MODULE__{hash: hash}, iodata?) do
    checksum(hash, iodata?)
  end

  def checksum(hash_string, iodata?) when is_binary(hash_string) do
    {:ok, hash} = Chain.string_to_address_hash(hash_string)
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
      {digit, _} when digit in ~c"0123456789" ->
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
      {digit, _} when digit in ~c"0123456789" ->
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
    Preloads provided contracts associations if address has contract_code which is not nil
  """
  @spec maybe_preload_smart_contract_associations(Address.t(), list, list) :: Address.t()
  def maybe_preload_smart_contract_associations(%Address{contract_code: nil} = address, _associations, _options),
    do: address

  def maybe_preload_smart_contract_associations(%Address{contract_code: _} = address, associations, options),
    do: Chain.select_repo(options).preload(address, associations)

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

  def fetched_coin_balance(address_hash) when not is_nil(address_hash) do
    Address
    |> where([address], address.hash == ^address_hash)
    |> select([address], address.fetched_coin_balance)
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

  @default_paging_options %PagingOptions{page_size: 50}
  @doc """
  Lists the top `t:Explorer.Chain.Address.t/0`'s' in descending order based on coin balance and address hash.

  """
  @spec list_top_addresses :: [{Address.t(), non_neg_integer()}]
  def list_top_addresses(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if is_nil(paging_options.key) do
      paging_options.page_size
      |> Accounts.take_enough()
      |> case do
        nil ->
          get_addresses(options)

        accounts ->
          Enum.map(
            accounts,
            &{&1, &1.transactions_count || 0}
          )
      end
    else
      fetch_top_addresses(options)
    end
  end

  @doc """
  Checks if given address is smart-contract
  """
  @spec smart_contract?(any()) :: boolean() | nil
  def smart_contract?(%__MODULE__{contract_code: nil}), do: false
  def smart_contract?(%__MODULE__{contract_code: _}), do: true
  def smart_contract?(%NotLoaded{}), do: nil
  def smart_contract?(_), do: false

  defp get_addresses(options) do
    accounts_with_n = fetch_top_addresses(options)

    accounts_with_n
    |> Enum.map(fn {address, _n} -> address end)
    |> Accounts.update()

    accounts_with_n
  end

  defp fetch_top_addresses(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, _hash}} ->
        []

      _ ->
        base_query =
          from(a in Address,
            where: a.fetched_coin_balance > ^0,
            order_by: [desc: a.fetched_coin_balance, asc: a.hash],
            preload: [:names, :smart_contract, :proxy_implementations],
            select: {a, a.transactions_count}
          )

        base_query
        |> page_addresses(paging_options)
        |> limit(^paging_options.page_size)
        |> Chain.select_repo(options).all()
    end
  end

  defp page_addresses(query, %PagingOptions{key: nil}), do: query

  defp page_addresses(query, %PagingOptions{key: {coin_balance, hash}}) do
    from(address in query,
      where:
        (address.fetched_coin_balance == ^coin_balance and address.hash > ^hash) or
          address.fetched_coin_balance < ^coin_balance
    )
  end

  @doc """
  Checks if an `t:Explorer.Chain.Address.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> Explorer.Address.check_address_exists(hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Address.check_address_exists(hash)
      :not_found

  """
  @spec check_address_exists(Hash.Address.t(), [Chain.api?()]) :: :ok | :not_found
  def check_address_exists(address_hash, options \\ []) do
    address_hash
    |> address_exists?(options)
    |> Chain.boolean_to_check_result()
  end

  @doc """
  Checks if an `t:Explorer.Chain.Address.t/0` with the given `hash` exists.

  Returns `true` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> Explorer.Chain.Address.address_exists?(hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.Address.address_exists?(hash)
      false

  """
  @spec address_exists?(Hash.Address.t(), [Chain.api?()]) :: boolean()
  def address_exists?(address_hash, options \\ []) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash
      )

    Chain.select_repo(options).exists?(query)
  end

  @doc """
  Sets contract_code for the given Explorer.Chain.Address
  """
  @spec set_contract_code(Hash.Address.t(), binary()) :: {non_neg_integer(), nil}
  def set_contract_code(address_hash, contract_code) when not is_nil(address_hash) and is_binary(contract_code) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(address in __MODULE__, where: address.hash == ^address_hash),
      [set: [contract_code: contract_code, updated_at: now]],
      timeout: @timeout
    )
  end
end
