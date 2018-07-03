defmodule Explorer.Chain.TokenTransfer do
  @moduledoc """
  Represents a token transfer between addresses.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Address, Hash, Log, Transaction, Token, TokenTransfer}

  @typedoc """
  * `:amount` - The token transferred amount
  * `:from_address` - The `t:Address.t/0` that sent the tokens
  * `:from_address_hash` - Address hash foreign key
  * `:to_address` - The `t:Address.t/0` that recieved the tokens
  * `:transaction` - The `t:Transaction.t/0` ledger
  * `:transaction_hash` - Transaction foreign key
  * `:log` - The `t:Log.t/0` record of the transfer
  * `:log_id` - Log foreign key
  * `:token` - The `t:Token.t/0` that was transferred
  * `:token_id` - Token foreign key
  """
  @type t :: %TokenTransfer{
          amount: Decimal.t(),
          from_address: Ecto.Association.NotLoaded.t() | Address.t(),
          from_address_hash: Hash.Truncated.t(),
          to_address: Ecto.Association.NotLoaded.t() | Address.t(),
          to_address_hash: Hash.Truncated.t(),
          transaction: Ecto.Association.NotLoaded.t() | Transaction.t(),
          transaction_hash: Hash.Full.t(),
          log: Ecto.Association.NotLoaded.t() | Log.t(),
          log_id: non_neg_integer(),
          token: Ecto.Association.NotLoaded.t() | Token.t(),
          token_id: non_neg_integer()
        }

  @constant "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  schema "token_transfers" do
    field(:amount, :decimal)

    belongs_to(:from_address, Address, foreign_key: :from_address_hash, references: :hash, type: Hash.Truncated)
    belongs_to(:to_address, Address, foreign_key: :to_address_hash, references: :hash, type: Hash.Truncated)
    belongs_to(:transaction, Transaction, foreign_key: :transaction_hash, references: :hash, type: Hash.Full)
    belongs_to(:log, Log)
    belongs_to(:token, Token)
  end

  @doc false
  def changeset(%TokenTransfer{} = struct, params \\ %{}) do
    struct
    |> cast(params, ~w(amount from_address_hash to_address_hash transaction_hash log_id token_id))
    |> assoc_constraint(:from_address)
    |> assoc_constraint(:to_address)
    |> assoc_constraint(:transaction)
    |> assoc_constraint(:log)
    |> assoc_constraint(:token)
    |> unique_constraint(:log_id)
  end

  @doc """
  Value that represents a token transfer in a `t:Explorer.Chain.Log.t/0`'s
  `first_topic` field.
  """
  def constant, do: @constant
end
