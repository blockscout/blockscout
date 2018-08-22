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

  use Ecto.Schema

  import Ecto.{Changeset, Query}

  alias Explorer.Chain.{Address, Block, Hash, Transaction, TokenTransfer}
  alias Explorer.{PagingOptions, Repo}
  alias Ecto.Adapters.SQL

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
  * `:amount` - The token transferred amount
  * `:from_address` - The `t:Explorer.Chain.Address.t/0` that sent the tokens
  * `:from_address_hash` - Address hash foreign key
  * `:to_address` - The `t:Explorer.Chain.Address.t/0` that recieved the tokens
  * `:to_address_hash` - Address hash foreign key
  * `:token_contract_address` - The `t:Explorer.Chain.Address.t/0` of the token's contract.
  * `:token_contract_address_hash` - Address hash foreign key
  * `:token_id` - ID of the token (applicable to ERC-721 tokens)
  * `:transaction` - The `t:Explorer.Chain.Transaction.t/0` ledger
  * `:transaction_hash` - Transaction foreign key
  * `:log_index` - Index of the corresponding `t:Explorer.Chain.Log.t/0` in the transaction.
  """
  @type t :: %TokenTransfer{
          amount: Decimal.t(),
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Address.t(),
          to_address: %Ecto.Association.NotLoaded{} | Address.t(),
          to_address_hash: Hash.Address.t(),
          token_contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          token_contract_address_hash: Hash.Address.t(),
          token_id: non_neg_integer() | nil,
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
          transaction_hash: Hash.Full.t(),
          log_index: non_neg_integer()
        }

  @typep paging_options :: {:paging_options, PagingOptions.t()}

  @constant "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  schema "token_transfers" do
    field(:amount, :decimal)
    field(:log_index, :integer)
    field(:token_id, :decimal)

    belongs_to(:from_address, Address, foreign_key: :from_address_hash, references: :hash, type: Hash.Address)
    belongs_to(:to_address, Address, foreign_key: :to_address_hash, references: :hash, type: Hash.Address)

    belongs_to(
      :token_contract_address,
      Address,
      foreign_key: :token_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)

    has_one(:token, through: [:token_contract_address, :token])

    timestamps()
  end

  @required_attrs ~w(log_index from_address_hash to_address_hash token_contract_address_hash transaction_hash)a
  @optional_attrs ~w(amount token_id)a

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

  @spec fetch_token_transfers_from_token_hash(Hash.t(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash(token_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(
        tt in TokenTransfer,
        join: t in Transaction,
        on: tt.transaction_hash == t.hash,
        join: b in Block,
        on: t.block_hash == b.hash,
        where: tt.token_contract_address_hash == ^token_address_hash,
        preload: [{:transaction, :block}, :token, :from_address, :to_address],
        order_by: [desc: b.timestamp]
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
        select: count(tt.id)
      )

    Repo.one(query)
  end

  @spec count_addresses_in_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_addresses_in_token_transfers_from_token_hash(token_address_hash) do
    {:ok, %{rows: [[result]]}} =
      SQL.query(
        Repo,
        """
          select count(*) as "addresses"
          from
          (
            select to_address_hash as "address_hash"
            from token_transfers tt1
            where tt1.token_contract_address_hash = $1

            union

            select from_address_hash as "address_hash"
            from token_transfers tt2
            where tt2.token_contract_address_hash = $1
          ) as addresses_count
        """,
        [token_address_hash.bytes]
      )

    result
  end

  def page_token_transfer(query, %PagingOptions{key: nil}), do: query

  def page_token_transfer(query, %PagingOptions{key: inserted_at}) do
    where(
      query,
      [token_transfer],
      token_transfer.inserted_at < ^inserted_at
    )
  end
end
