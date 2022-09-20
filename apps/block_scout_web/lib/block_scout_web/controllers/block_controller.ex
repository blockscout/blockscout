defmodule BlockScoutWeb.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{BlockView, Controller}
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, params) do
    case params["block_type"] do
      "Uncle" ->
        uncle(conn, params)

      "Reorg" ->
        reorg(conn, params)

      _ ->
        [
          necessity_by_association: %{
            :transactions => :optional,
            [miner: :names] => :optional,
            :rewards => :optional
          },
          block_type: "Block"
        ]
        |> handle_render(conn, params)
    end
  end

  def show(conn, %{"hash_or_number" => hash_or_number}) do
    block_transaction_path =
      conn
      |> block_transaction_path(:index, hash_or_number)
      |> Controller.full_path()

    redirect(conn, to: block_transaction_path)
  end

  def reorg(conn, params) do
    [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional,
        :rewards => :optional
      },
      block_type: "Reorg"
    ]
    |> handle_render(conn, params)
  end

  def uncle(conn, params) do
    [
      necessity_by_association: %{
        :transactions => :optional,
        [miner: :names] => :optional,
        :nephews => :required,
        :rewards => :optional
      },
      block_type: "Uncle"
    ]
    |> handle_render(conn, params)
  end

  defp handle_render(full_options, conn, %{"type" => "JSON"} = params) do
    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Chain.list_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    block_type = Keyword.get(full_options, :block_type, "Block")

    next_page_path =
      case next_page_params(next_page, blocks, params) do
        nil ->
          nil

        next_page_params ->
          params_with_block_type =
            next_page_params
            |> Map.delete("type")
            |> Map.put("block_type", block_type)

          blocks_path(
            conn,
            :index,
            params_with_block_type
          )
      end

    json(
      conn,
      %{
        items:
          Enum.map(blocks, fn block ->
            View.render_to_string(
              BlockView,
              "_tile.html",
              block: block,
              block_type: block_type
            )
          end),
        next_page_path: next_page_path
      }
    )
  end

  defp handle_render(full_options, conn, %{"api" => "true"} = params) do
    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Chain.list_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    block_type = Keyword.get(full_options, :block_type, "Block")

    next_page_path =
      case next_page_params(next_page, blocks, params) do
        nil ->
          nil

        next_page_params ->
          params_with_block_type =
            next_page_params
            |> Map.delete("type")
            |> Map.put("block_type", block_type)

          blocks_path(
            conn,
            :index,
            params_with_block_type
          )
      end

    json(
      conn,
      %{
        items: blocks,
        next_page_path: next_page_path
      }
    )
  end

  defp handle_render(full_options, conn, _params) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      block_type: Keyword.get(full_options, :block_type, "Block")
    )
  end
end
