defmodule BlockScoutWeb.BlockWithdrawalController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.BlockTransactionController, only: [param_block_hash_or_number_to_block: 2, block_above_tip: 1]

  alias BlockScoutWeb.{BlockTransactionView, BlockWithdrawalView, Controller}
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number, "type" => "JSON"} = params) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number, []) do
      {:ok, block} ->
        full_options =
          [necessity_by_association: %{address: :optional}]
          |> Keyword.merge(paging_options(params))

        withdrawals_plus_one = Chain.block_to_withdrawals(block.hash, full_options)

        {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

        next_page_path =
          case next_page_params(next_page, withdrawals, params) do
            nil ->
              nil

            next_page_params ->
              block_withdrawal_path(
                conn,
                :index,
                block,
                Map.delete(next_page_params, "type")
              )
          end

        items =
          for withdrawal <- withdrawals do
            View.render_to_string(BlockWithdrawalView, "_withdrawal.html", withdrawal: withdrawal)
          end

        json(
          conn,
          %{
            items: items,
            next_page_path: next_page_path
          }
        )

      {:error, {:invalid, :hash}} ->
        not_found(conn)

      {:error, {:invalid, :number}} ->
        not_found(conn)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(
          BlockTransactionView,
          "404.html",
          block: nil,
          block_above_tip: block_above_tip(formatted_block_hash_or_number)
        )
    end
  end

  def index(conn, %{"block_hash_or_number" => formatted_block_hash_or_number}) do
    case param_block_hash_or_number_to_block(formatted_block_hash_or_number,
           necessity_by_association: %{
             [miner: :names] => :required,
             :uncles => :optional,
             :nephews => :optional,
             :rewards => :optional
           }
         ) do
      {:ok, block} ->
        block_transaction_count = Chain.block_to_transaction_count(block.hash)

        render(
          conn,
          "index.html",
          block: block,
          block_transaction_count: block_transaction_count,
          current_path: Controller.current_full_path(conn)
        )

      {:error, {:invalid, :hash}} ->
        not_found(conn)

      {:error, {:invalid, :number}} ->
        not_found(conn)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(
          BlockTransactionView,
          "404.html",
          block: nil,
          block_above_tip: block_above_tip(formatted_block_hash_or_number)
        )
    end
  end
end
