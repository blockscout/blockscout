defmodule Explorer.Chain.Block do
  @moduledoc """
  A package of data that contains zero or more transactions, the hash of the previous block ("parent"), and optionally
  other data. Because each block (except for the initial "genesis block") points to the previous block, the data
  structure that they form is called a "blockchain".
  """

  use Explorer.Schema

  alias Ecto.Changeset
  alias Explorer.Chain.{Gas, Hash, Transaction}

  # Types

  @typedoc """
  How much work is required to find a hash with some number of leading 0s.  It is measured in hashes for PoW
  (Proof-of-Work) chains like Ethereum.  In PoA (Proof-of-Authority) chains, it does not apply as blocks are validated
  in a round-robin fashion, and so the value is always `Decimal.new(0)`.
  """
  @type difficulty :: Decimal.t()

  @typedoc """
  Number of the block in the chain.
  """
  @type block_number :: non_neg_integer()

  @typedoc """
  * `difficulty` - how hard the block was to mine.
  * `gas_limit` - If the total number of gas used by the computation spawned by the transaction, including the original
      message and any sub-messages that may be triggered, is less than or equal to the gas limit, then the transaction
      processes. If the total gas exceeds the gas limit, then all changes are reverted, except that the transaction is
      still valid and the fee can still be collected by the miner.
  * `gas_used` - The actual `t:gas/0` used to mine/validate the transactions in the block.
  * `hash` - the hash of the block.
  * `miner` - the hash of the `t:Explorer.Address.t/0` of the miner.  In Proof-of-Authority chains, this is the
      validator.
  * `nonce` - the hash of the generated proof-of-work.  Not used in Proof-of-Authority chains.
  * `number` - which block this is along the chain.
  * `parent_hash` - the hash of the parent block, which should have the previous `number`
  * `size` - The size of the block in bytes.
  * `timestamp` - When the block was collated
  * `total_diffficulty` - the total `difficulty` of the chain until this block.
  * `transactions` - the `t:Explorer.Chain.Transaction.t/0` in this block.
  """
  @type t :: %__MODULE__{
          difficulty: difficulty(),
          gas_limit: Gas.t(),
          gas_used: Gas.t(),
          hash: Hash.t(),
          miner: Address.hash(),
          nonce: Hash.t(),
          number: block_number(),
          parent_hash: Hash.t(),
          size: non_neg_integer(),
          timestamp: DateTime.t(),
          total_difficulty: difficulty(),
          transactions: %Ecto.Association.NotLoaded{} | [Transaction.t()]
        }

  schema "blocks" do
    field(:difficulty, :decimal)
    field(:gas_limit, :integer)
    field(:gas_used, :integer)
    field(:hash, :string)
    field(:miner, :string)
    field(:nonce, :string)
    field(:number, :integer)
    field(:parent_hash, :string)
    field(:size, :integer)
    field(:timestamp, Timex.Ecto.DateTime)
    field(:total_difficulty, :decimal)

    timestamps()

    has_many(:transactions, Transaction)
  end

  @required_attrs ~w(difficulty gas_limit gas_used hash miner nonce number parent_hash size timestamp total_difficulty)a

  @doc false
  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end

  @doc false
  def extract(raw_block, %{} = timestamps) do
    raw_block
    |> extract_block(timestamps)
    |> extract_transactions(raw_block["transactions"], timestamps)
  end

  def null, do: %__MODULE__{number: -1, timestamp: :calendar.universal_time()}

  def latest(query) do
    query |> order_by(desc: :number)
  end

  ## Private Functions

  defp extract_block(raw_block, %{} = timestamps) do
    attrs = %{
      hash: raw_block["hash"],
      number: raw_block["number"],
      gas_used: raw_block["gasUsed"],
      timestamp: raw_block["timestamp"],
      parent_hash: raw_block["parentHash"],
      miner: raw_block["miner"],
      difficulty: raw_block["difficulty"],
      total_difficulty: raw_block["totalDifficulty"],
      size: raw_block["size"],
      gas_limit: raw_block["gasLimit"],
      nonce: raw_block["nonce"] || "0"
    }

    case changeset(%__MODULE__{}, attrs) do
      %Changeset{valid?: true, changes: changes} -> {:ok, Map.merge(changes, timestamps)}
      %Changeset{valid?: false, errors: errors} -> {:error, {:block, errors}}
    end
  end

  defp extract_transactions({:ok, block_changes}, raw_transactions, %{} = timestamps) do
    raw_transactions
    |> Enum.map(&Transaction.decode(&1, block_changes.number, timestamps))
    |> Enum.reduce_while({:ok, block_changes, []}, fn
      {:ok, trans_changes}, {:ok, block, acc} ->
        {:cont, {:ok, block, [trans_changes | acc]}}

      {:error, reason}, _ ->
        {:halt, {:error, {:transaction, reason}}}
    end)
  end

  defp extract_transactions({:error, reason}, _transactions, _timestamps) do
    {:error, reason}
  end
end
