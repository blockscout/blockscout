defmodule Explorer.Chain.Shibarium.Reader do
  @moduledoc "Contains read functions for Shibarium modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2
    ]

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Chain.Shibarium.Bridge
  alias Explorer.PagingOptions

  @doc """
  Returns a list of completed Shibarium deposits to display them in UI.
  """
  @spec deposits(list()) :: list()
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(
            sb in Bridge,
            where: sb.operation_type == :deposit and not is_nil(sb.l1_block_number) and not is_nil(sb.l2_block_number),
            select: %{
              l1_block_number: sb.l1_block_number,
              l1_transaction_hash: sb.l1_transaction_hash,
              l2_transaction_hash: sb.l2_transaction_hash,
              user: sb.user,
              timestamp: sb.timestamp
            },
            order_by: [desc: sb.l1_block_number]
          )

        base_query
        |> page_deposits(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
  Returns a total number of completed Shibarium deposits.
  """
  @spec deposits_count(list()) :: term() | nil
  def deposits_count(options \\ []) do
    query =
      from(
        sb in Bridge,
        where: sb.operation_type == :deposit and not is_nil(sb.l1_block_number) and not is_nil(sb.l2_block_number)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @doc """
  Returns a list of completed Shibarium withdrawals to display them in UI.
  """
  @spec withdrawals(list()) :: list()
  def withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: 0} ->
        []

      _ ->
        base_query =
          from(
            sb in Bridge,
            where:
              sb.operation_type == :withdrawal and not is_nil(sb.l1_block_number) and not is_nil(sb.l2_block_number),
            select: %{
              l2_block_number: sb.l2_block_number,
              l2_transaction_hash: sb.l2_transaction_hash,
              l1_transaction_hash: sb.l1_transaction_hash,
              user: sb.user,
              timestamp: sb.timestamp
            },
            order_by: [desc: sb.l2_block_number]
          )

        base_query
        |> page_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
  Returns a total number of completed Shibarium withdrawals.
  """
  @spec withdrawals_count(list()) :: term() | nil
  def withdrawals_count(options \\ []) do
    query =
      from(
        sb in Bridge,
        where: sb.operation_type == :withdrawal and not is_nil(sb.l1_block_number) and not is_nil(sb.l2_block_number)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  defp page_deposits(query, %PagingOptions{key: nil}), do: query

  defp page_deposits(query, %PagingOptions{key: {block_number}}) do
    from(item in query, where: item.l1_block_number < ^block_number)
  end

  defp page_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_withdrawals(query, %PagingOptions{key: {block_number}}) do
    from(item in query, where: item.l2_block_number < ^block_number)
  end
end
