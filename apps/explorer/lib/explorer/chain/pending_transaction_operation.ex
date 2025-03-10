defmodule Explorer.Chain.PendingTransactionOperation do
  @moduledoc """
  Tracks a transaction that has pending operations.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Repo

  @required_attrs ~w(transaction_hash)a

  @typedoc """
   * `transaction_hash` - the hash of the transaction that has pending operations.
  """
  @primary_key false
  typed_schema "pending_transaction_operations" do
    timestamps()

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Returns the count of pending blocks in provided range
    (between `from_block_number` and `to_block_number`).
  """
  @spec blocks_count_in_range(integer(), integer()) :: integer()
  def blocks_count_in_range(from_block_number, to_block_number) when from_block_number <= to_block_number do
    __MODULE__
    |> join(:inner, [pto], t in assoc(pto, :transaction))
    |> where([_pto, t], t.block_number >= ^from_block_number)
    |> where([_pto, t], t.block_number <= ^to_block_number)
    |> select([_pto, t], count(t.block_number, :distinct))
    |> Repo.one()
  end

  @doc """
  Returns a stream of all transactions with unfetched internal transactions, using
  the `pending_transaction_operation` table.
      iex> unfetched_block = insert(:block)
      iex> unfetched_transaction = insert(:transaction) |> with_block(unfetched_block)
      iex> insert(:pending_transaction_operation, transaction: unfetched_transaction)
      iex> {:ok, transaction_params_set} = Explorer.Chain.stream_transactions_with_unfetched_internal_transactions(
      ...>   MapSet.new(),
      ...>   fn transaction_params, acc ->
      ...>     MapSet.put(acc, transaction_params)
      ...>   end
      ...> )
      iex> %{
      ...>   block_number: unfetched_transaction.block_number,
      ...>   hash: unfetched_transaction.hash,
      ...>   index: unfetched_transaction.index
      ...> } in transaction_params_set
      true
  """
  @spec stream_transactions_with_unfetched_internal_transactions(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_transactions_with_unfetched_internal_transactions(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    direction = Application.get_env(:indexer, :internal_transactions_fetch_order)

    query =
      from(
        po in __MODULE__,
        join: t in assoc(po, :transaction),
        select: %{block_number: t.block_number, hash: t.hash, index: t.index},
        order_by: [{^direction, t.block_number}]
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
