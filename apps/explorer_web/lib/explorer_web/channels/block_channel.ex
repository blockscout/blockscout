defmodule ExplorerWeb.BlockChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block events.
  """
  use ExplorerWeb, :channel

  alias ExplorerWeb.{BlockView, ChainView}
  alias Phoenix.View

  intercept(["new_block"])

  def join("blocks:new_block", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("new_block", %{block: block}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered_block =
      View.render_to_string(
        BlockView,
        "_tile.html",
        locale: socket.assigns.locale,
        block: block
      )

    rendered_homepage_block =
      View.render_to_string(
        ChainView,
        "_block.html",
        locale: socket.assigns.locale,
        block: block
      )

    push(socket, "new_block", %{
      homepage_block_html: rendered_homepage_block,
      block_html: rendered_block,
      blockNumber: block.number
    })

    {:noreply, socket}
  end
end
