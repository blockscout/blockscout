defmodule BlockScoutWeb.BlockChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.{BlockView, ChainView}
  alias Phoenix.View

  intercept(["new_block"])

  def join("blocks:new_block", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("new_block", %{block: block, average_block_time: average_block_time}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_block =
      View.render_to_string(
        BlockView,
        "_tile.html",
        locale: socket.assigns.locale,
        block: block
      )

    rendered_chain_block =
      View.render_to_string(
        ChainView,
        "_block.html",
        locale: socket.assigns.locale,
        block: block
      )

    push(socket, "new_block", %{
      average_block_time: Timex.format_duration(average_block_time, :humanized),
      chain_block_html: rendered_chain_block,
      block_html: rendered_block,
      block_number: block.number
    })

    {:noreply, socket}
  end
end
