defmodule BlockScoutWeb.BlockChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.API.V2.BlockView, as: BlockViewAPI
  alias BlockScoutWeb.{BlockView, ChainView}
  alias Phoenix.View
  alias Timex.Duration

  intercept(["new_block"])

  def join("blocks:new_block", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("blocks:" <> _miner_address, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "new_block",
        %{block: block, average_block_time: average_block_time},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    rendered_block = BlockViewAPI.render("block.json", %{block: block, socket: nil})

    push(socket, "new_block", %{
      average_block_time: to_string(Duration.to_milliseconds(average_block_time)),
      block: rendered_block
    })

    {:noreply, socket}
  end

  def handle_out("new_block", %{block: block, average_block_time: average_block_time}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_block =
      View.render_to_string(
        BlockView,
        "_tile.html",
        block: block,
        block_type: BlockView.block_type(block)
      )

    rendered_chain_block =
      View.render_to_string(
        ChainView,
        "_block.html",
        block: block
      )

    push(socket, "new_block", %{
      average_block_time: Timex.format_duration(average_block_time, Explorer.Counters.AverageBlockTimeDurationFormatShortened),
      chain_block_html: rendered_chain_block,
      block_html: rendered_block,
      block_number: block.number,
      block_miner_hash: to_string(block.miner_hash)
    })

    {:noreply, socket}
  end
end
