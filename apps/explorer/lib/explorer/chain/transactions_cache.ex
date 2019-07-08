defmodule Explorer.Chain.TransactionsCache do
  @moduledoc """
  Caches the latest imported transactions
  """

  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @transactions_ids_key "transactions_ids"
  @cache_name :transactions
  @max_size 51
  @preloads [
    :block,
    created_contract_address: :names,
    from_address: :names,
    to_address: :names,
    token_transfers: :token,
    token_transfers: :from_address,
    token_transfers: :to_address
  ]

  @spec cache_name :: atom()
  def cache_name, do: @cache_name

  @doc """
  Fetches a transaction from its id ({block_number, index}), returns nil if not found
  """
  @spec get({non_neg_integer(), non_neg_integer()}) :: Transaction.t() | nil
  def get(id), do: ConCache.get(@cache_name, id)

  @doc """
  Return the current number of transactions stored
  """
  @spec size :: non_neg_integer()
  def size, do: Enum.count(transactions_ids())

  @doc """
  Checks if there are enough transactions stored
  """
  @spec enough?(non_neg_integer()) :: boolean()
  def enough?(amount) do
    amount <= size()
  end

  @doc """
  Checks if the number of transactions stored is already the max allowed
  """
  @spec full? :: boolean()
  def full? do
    @max_size <= size()
  end

  @doc "Returns the list ids of the transactions currently stored"
  @spec transactions_ids :: [{non_neg_integer(), non_neg_integer()}]
  def transactions_ids do
    ConCache.get(@cache_name, @transactions_ids_key) || []
  end

  @doc "Returns all the stored transactions"
  @spec all :: [Transaction.t()]
  def all, do: Enum.map(transactions_ids(), &get(&1))

  @doc "Returns the `n` most recent transactions stored"
  @spec take(integer()) :: [Transaction.t()]
  def take(amount) do
    transactions_ids()
    |> Enum.take(amount)
    |> Enum.map(&get(&1))
  end

  @doc """
  Returns the `n` most recent transactions, unless there are not as many stored,
  in which case returns `nil`
  """
  @spec take_enough(integer()) :: [Transaction.t()] | nil
  def take_enough(amount) do
    if enough?(amount), do: take(amount)
  end

  @doc """
  Adds a transaction (or a list of transactions).
  If the cache is already full, the transaction will be only stored if it can take
  the place of a less recent one.
  NOTE: each transaction is inserted atomically
  """
  @spec update([Transaction.t()] | Transaction.t() | nil) :: :ok
  def update(transactions) when is_nil(transactions), do: :ok

  def update(transactions) when is_list(transactions) do
    Enum.map(transactions, &update(&1))
  end

  def update(transaction) do
    ConCache.isolated(@cache_name, @transactions_ids_key, fn ->
      transaction_id = {transaction.block_number, transaction.index}
      ids = transactions_ids()

      if full?() do
        {init, [min]} = Enum.split(ids, -1)

        cond do
          transaction_id < min ->
            :ok

          transaction_id > min ->
            insert_transaction(transaction_id, transaction, init)
            ConCache.delete(@cache_name, min)

          transaction_id == min ->
            put_transaction(transaction_id, transaction)
        end
      else
        insert_transaction(transaction_id, transaction, ids)
      end
    end)
  end

  defp insert_transaction(transaction_id, transaction, ids) do
    put_transaction(transaction_id, transaction)

    ConCache.put(@cache_name, @transactions_ids_key, insert_sorted(transaction_id, ids))
  end

  defp put_transaction(transaction_id, transaction) do
    full_transaction = Repo.preload(transaction, @preloads)

    ConCache.put(@cache_name, transaction_id, full_transaction)
  end

  defp insert_sorted(id, ids) do
    case ids do
      [] ->
        [id]

      [head | tail] ->
        cond do
          head > id -> [head | insert_sorted(id, tail)]
          head < id -> [id | ids]
          head == id -> ids
        end
    end
  end
end
