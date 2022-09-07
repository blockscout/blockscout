defmodule Explorer.Chain.TokenTransfer do
  @moduledoc """
  Represents a token transfer between addresses for a given token.

  ## Overview

  Token transfers are special cases from a `t:Explorer.Chain.Log.t/0`. A token
  transfer is always signified by the value from the `first_topic` in a log. That value
  is always `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef`.

  ## Data Mapping From a Log

  Here's how a log's data maps to a token transfer:

  | Log                 | Token Transfer                 | Description                     |
  |---------------------|--------------------------------|---------------------------------|
  | `:second_topic`     | `:from_address_hash`           | Address sending tokens          |
  | `:third_topic`      | `:to_address_hash`             | Address receiving tokens        |
  | `:data`             | `:amount`                      | Amount of tokens transferred    |
  | `:transaction_hash` | `:transaction_hash`            | Transaction of the transfer     |
  | `:address_hash`     | `:token_contract_address_hash` | Address of token's contract     |
  | `:index`            | `:log_index`                   | Index of log in transaction     |
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, limit: 2, where: 3]

  alias Explorer.Chain.{Address, Block, Hash, TokenTransfer, Transaction}
  alias Explorer.Chain.Token.Instance
  alias Explorer.{PagingOptions, Repo}

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
  * `:amount` - The token transferred amount
  * `:block_hash` - hash of the block
  * `:block_number` - The block number that the transfer took place.
  * `:from_address` - The `t:Explorer.Chain.Address.t/0` that sent the tokens
  * `:from_address_hash` - Address hash foreign key
  * `:to_address` - The `t:Explorer.Chain.Address.t/0` that received the tokens
  * `:to_address_hash` - Address hash foreign key
  * `:token_contract_address` - The `t:Explorer.Chain.Address.t/0` of the token's contract.
  * `:token_contract_address_hash` - Address hash foreign key
  * `:token_id` - ID of the token (applicable to ERC-721 tokens)
  * `:transaction` - The `t:Explorer.Chain.Transaction.t/0` ledger
  * `:transaction_hash` - Transaction foreign key
  * `:log_index` - Index of the corresponding `t:Explorer.Chain.Log.t/0` in the transaction.
  * `:amounts` - Tokens transferred amounts in case of batched transfer in ERC-1155
  * `:token_ids` - IDs of the tokens (applicable to ERC-1155 tokens)
  """
  @type t :: %TokenTransfer{
          amount: Decimal.t() | nil,
          block_number: non_neg_integer() | nil,
          block_hash: Hash.Full.t(),
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Address.t(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_hash: Hash.Address.t(),
          token_contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          token_contract_address_hash: Hash.Address.t(),
          token_id: non_neg_integer() | nil,
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Hash.Full.t(),
          log_index: non_neg_integer(),
          amounts: [Decimal.t()] | nil,
          token_ids: [non_neg_integer()] | nil
        }

  @typep paging_options :: {:paging_options, PagingOptions.t()}

  @constant "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @erc1155_single_transfer_signature "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
  @erc1155_batch_transfer_signature "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb"

  @transfer_function_signature "0xa9059cbb"

  @primary_key false
  schema "token_transfers" do
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:log_index, :integer, primary_key: true)
    field(:token_id, :decimal)
    field(:amounts, {:array, :decimal})
    field(:token_ids, {:array, :decimal})

    belongs_to(:from_address, Address, foreign_key: :from_address_hash, references: :hash, type: Hash.Address)
    belongs_to(:to_address, Address, foreign_key: :to_address_hash, references: :hash, type: Hash.Address)

    belongs_to(
      :token_contract_address,
      Address,
      foreign_key: :token_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    has_one(
      :instance,
      Instance,
      foreign_key: :token_contract_address_hash,
      references: :token_contract_address_hash
    )

    has_one(:token, through: [:token_contract_address, :token])

    timestamps()
  end

  @required_attrs ~w(block_number log_index from_address_hash to_address_hash token_contract_address_hash transaction_hash block_hash)a
  @optional_attrs ~w(amount token_id amounts token_ids)a

  @doc false
  def changeset(%TokenTransfer{} = struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:from_address)
    |> foreign_key_constraint(:to_address)
    |> foreign_key_constraint(:token_contract_address)
    |> foreign_key_constraint(:transaction)
  end

  @doc """
  Value that represents a token transfer in a `t:Explorer.Chain.Log.t/0`'s
  `first_topic` field.
  """
  def constant, do: @constant

  def erc1155_single_transfer_signature, do: @erc1155_single_transfer_signature

  def erc1155_batch_transfer_signature, do: @erc1155_batch_transfer_signature

  @doc """
  ERC 20's transfer(address,uint256) function signature
  """
  def transfer_function_signature, do: @transfer_function_signature

  @spec fetch_token_transfers_from_token_hash(Hash.t(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash(token_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(
        tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number),
        preload: [:transaction, :token, :from_address, :to_address],
        order_by: [desc: tt.block_number]
      )

    query
    |> page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  @spec fetch_token_transfers_from_token_hash_and_token_id(Hash.t(), binary(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(
        tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^token_address_hash,
        where: tt.token_id == ^token_id or fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^Decimal.new(token_id)),
        where: not is_nil(tt.block_number),
        preload: [:transaction, :token, :from_address, :to_address],
        order_by: [desc: tt.block_number]
      )

    query
    |> page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  @spec count_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_token_transfers_from_token_hash(token_address_hash) do
    query =
      from(
        tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^token_address_hash,
        select: fragment("COUNT(*)")
      )

    Repo.one(query, timeout: :infinity)
  end

  @spec count_token_transfers_from_token_hash_and_token_id(Hash.t(), binary()) :: non_neg_integer()
  def count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id) do
    query =
      from(
        tt in TokenTransfer,
        where:
          tt.token_contract_address_hash == ^token_address_hash and
            (tt.token_id == ^token_id or fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^Decimal.new(token_id))),
        select: fragment("COUNT(*)")
      )

    Repo.one(query, timeout: :infinity)
  end

  def page_token_transfer(query, %PagingOptions{key: nil}), do: query

  def page_token_transfer(query, %PagingOptions{key: {token_id}, asc_order: true}) do
    where(query, [tt], tt.token_id > ^token_id)
  end

  def page_token_transfer(query, %PagingOptions{key: {token_id}}) do
    where(query, [tt], tt.token_id < ^token_id)
  end

  def page_token_transfer(query, %PagingOptions{key: {block_number, log_index}, asc_order: true}) do
    where(
      query,
      [tt],
      tt.block_number > ^block_number or (tt.block_number == ^block_number and tt.log_index > ^log_index)
    )
  end

  def page_token_transfer(query, %PagingOptions{key: {block_number, log_index}}) do
    where(
      query,
      [tt],
      tt.block_number < ^block_number or (tt.block_number == ^block_number and tt.log_index < ^log_index)
    )
  end

  @doc """
  Fetches the transaction hashes from token transfers according
  to the address hash.
  """
  def where_any_address_fields_match(:to, address_hash, paging_options) do
    query =
      from(
        tt in TokenTransfer,
        where: tt.to_address_hash == ^address_hash,
        select: type(tt.transaction_hash, :binary),
        distinct: tt.transaction_hash
      )

    query
    |> page_transaction_hashes_from_token_transfers(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  def where_any_address_fields_match(:from, address_hash, paging_options) do
    query =
      from(
        tt in TokenTransfer,
        where: tt.from_address_hash == ^address_hash,
        select: type(tt.transaction_hash, :binary),
        distinct: tt.transaction_hash
      )

    query
    |> page_transaction_hashes_from_token_transfers(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  def where_any_address_fields_match(_, address_hash, paging_options) do
    {:ok, address_bytes} = Explorer.Chain.Hash.Address.dump(address_hash)

    transaction_hashes_from_token_transfers_sql(address_bytes, paging_options)
  end

  defp transaction_hashes_from_token_transfers_sql(address_bytes, %PagingOptions{page_size: page_size} = paging_options) do
    query =
      from(token_transfer in TokenTransfer,
        where: token_transfer.to_address_hash == ^address_bytes or token_transfer.from_address_hash == ^address_bytes,
        select: type(token_transfer.transaction_hash, :binary),
        distinct: token_transfer.transaction_hash,
        limit: ^page_size
      )

    query
    |> page_transaction_hashes_from_token_transfers(paging_options)
    |> Repo.all()
  end

  defp page_transaction_hashes_from_token_transfers(query, %PagingOptions{key: nil}), do: query

  defp page_transaction_hashes_from_token_transfers(query, %PagingOptions{key: {block_number, _index}}) do
    where(
      query,
      [tt],
      tt.block_number < ^block_number
    )
  end

  @doc """
  Innventory tab query.
  A token ERC-721 is considered unique because it corresponds to the possession
  of a specific asset.

  To find out its current owner, it is necessary to look at the token last
  transfer.
  """
  @spec address_to_unique_tokens(Hash.Address.t()) :: Ecto.Query.t()
  def address_to_unique_tokens(contract_address_hash) do
    from(
      tt in TokenTransfer,
      left_join: instance in Instance,
      on: tt.token_contract_address_hash == instance.token_contract_address_hash and tt.token_id == instance.token_id,
      where: tt.token_contract_address_hash == ^contract_address_hash,
      where: tt.to_address_hash != ^"0x0000000000000000000000000000000000000000",
      order_by: [desc: tt.block_number],
      distinct: [desc: tt.token_id],
      preload: [:to_address],
      select: %{tt | instance: instance}
    )
  end
end
