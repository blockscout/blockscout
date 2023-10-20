defmodule Explorer.Chain.PolygonEdge.Reader do
  @moduledoc "Contains read functions for Polygon Edge modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2
    ]

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain.PolygonEdge.{Deposit, DepositExecute, Withdrawal, WithdrawalExit}
  alias Explorer.Chain.{Block, Hash}

  @spec deposits(list()) :: list()
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        de in DepositExecute,
        inner_join: d in Deposit,
        on: d.msg_id == de.msg_id and not is_nil(d.l1_timestamp),
        select: %{
          msg_id: de.msg_id,
          from: d.from,
          to: d.to,
          l1_transaction_hash: d.l1_transaction_hash,
          l1_timestamp: d.l1_timestamp,
          success: de.success,
          l2_transaction_hash: de.l2_transaction_hash
        },
        order_by: [desc: de.msg_id]
      )

    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec deposits_count(list()) :: term() | nil
  def deposits_count(options \\ []) do
    query =
      from(
        de in DepositExecute,
        inner_join: d in Deposit,
        on: d.msg_id == de.msg_id and not is_nil(d.l1_timestamp)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @spec withdrawals(list()) :: list()
  def withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(
        w in Withdrawal,
        left_join: we in WithdrawalExit,
        on: we.msg_id == w.msg_id,
        left_join: b in Block,
        on: b.number == w.l2_block_number and b.consensus == true,
        select: %{
          msg_id: w.msg_id,
          from: w.from,
          to: w.to,
          l2_transaction_hash: w.l2_transaction_hash,
          l2_timestamp: b.timestamp,
          success: we.success,
          l1_transaction_hash: we.l1_transaction_hash
        },
        where: not is_nil(w.from),
        order_by: [desc: w.msg_id]
      )

    base_query
    |> page_deposits_or_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @spec withdrawals_count(list()) :: term() | nil
  def withdrawals_count(options \\ []) do
    query =
      from(
        w in Withdrawal,
        where: not is_nil(w.from)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @spec deposit_by_transaction_hash(Hash.t()) :: Ecto.Schema.t() | term() | nil
  def deposit_by_transaction_hash(hash) do
    query =
      from(
        de in DepositExecute,
        inner_join: d in Deposit,
        on: d.msg_id == de.msg_id and not is_nil(d.from),
        select: %{
          msg_id: de.msg_id,
          from: d.from,
          to: d.to,
          success: de.success,
          l1_transaction_hash: d.l1_transaction_hash
        },
        where: de.l2_transaction_hash == ^hash
      )

    Repo.replica().one(query)
  end

  @spec withdrawal_by_transaction_hash(Hash.t()) :: Ecto.Schema.t() | term() | nil
  def withdrawal_by_transaction_hash(hash) do
    query =
      from(
        w in Withdrawal,
        left_join: we in WithdrawalExit,
        on: we.msg_id == w.msg_id,
        select: %{
          msg_id: w.msg_id,
          from: w.from,
          to: w.to,
          success: we.success,
          l1_transaction_hash: we.l1_transaction_hash
        },
        where: w.l2_transaction_hash == ^hash and not is_nil(w.from)
      )

    Repo.replica().one(query)
  end

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: {msg_id}}) do
    from(item in query, where: item.msg_id < ^msg_id)
  end
end
