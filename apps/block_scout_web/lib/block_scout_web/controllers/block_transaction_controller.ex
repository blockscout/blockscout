defmodule BlockScoutWeb.BlockTransactionController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import Explorer.Chain, only: [hash_to_block: 2, number_to_block: 2, string_to_block_hash: 1]

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number, "type" => "JSON"} = params) do
    with {:ok, block} <-
           param_block_hash_or_number_to_block(formatted_block_hash_or_number, []) do
      full_options =
        Keyword.merge(
          [
            necessity_by_association: %{
              :block => :required,
              [created_contract_address: :names] => :optional,
              [from_address: :names] => :required,
              [to_address: :names] => :optional
            }
          ],
          paging_options(params)
        )

      transactions_plus_one = Chain.block_to_transactions(block, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_path =
        case next_page_params(next_page, transactions, params) do
          nil ->
            nil

          next_page_params ->
            block_transaction_path(
              conn,
              :index,
              block,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        transactions
        |> Enum.map(fn transaction ->
          View.render_to_string(
            TransactionView,
            "_tile.html",
            transaction: transaction
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
      )
    else
      {:error, {:invalid, :hash}} ->
        not_found(conn)

      {:error, {:invalid, :number}} ->
        not_found(conn)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(
          "404.html",
          block: nil,
          block_above_tip: block_above_tip(formatted_block_hash_or_number)
        )
    end
  end

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number}) do
    with {:ok, block} <-
           param_block_hash_or_number_to_block(formatted_block_hash_or_number,
             necessity_by_association: %{
               [miner: :names] => :required,
               :uncles => :optional,
               :nephews => :optional,
               :rewards => :optional
             }
           ) do
      block_transaction_count = Chain.block_to_transaction_count(block)

      render(
        conn,
        "index.html",
        block: block,
        block_transaction_count: block_transaction_count,
        current_path: current_path(conn)
      )
    else
      {:error, {:invalid, :hash}} ->
        not_found(conn)

      {:error, {:invalid, :number}} ->
        not_found(conn)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(
          "404.html",
          block: nil,
          block_above_tip: block_above_tip(formatted_block_hash_or_number)
        )
    end
  end

  defp param_block_hash_or_number_to_block("0x" <> _ = param, options) do
    with {:ok, hash} <- string_to_block_hash(param) do
      hash_to_block(hash, options)
    else
      :error -> {:error, {:invalid, :hash}}
    end
  end

  defp param_block_hash_or_number_to_block(number_string, options)
       when is_binary(number_string) do
    with {:ok, number} <- BlockScoutWeb.Chain.param_to_block_number(number_string) do
      number_to_block(number, options)
    else
      {:error, :invalid} -> {:error, {:invalid, :number}}
    end
  end

  defp block_above_tip("0x" <> _), do: {:error, :hash}

  defp block_above_tip(block_hash_or_number) when is_binary(block_hash_or_number) do
    case Chain.max_consensus_block_number() do
      {:ok, max_consensus_block_number} ->
        {block_number, _} = Integer.parse(block_hash_or_number)
        {:ok, block_number > max_consensus_block_number}

      {:error, :not_found} ->
        {:ok, true}
    end
  end
end
