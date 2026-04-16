defmodule BlockScoutWeb.API.Legacy.BlockView do
  @moduledoc false

  alias BlockScoutWeb.API.RPC.BlockView, as: V1BlockView

  # The v1 controller calls render/2 without a template name on the success path;
  # Phoenix derives it from conn.private.phoenix_action, which for this wrapper is
  # :get_block_number_by_time → "get_block_number_by_time.json". Bridge that to the
  # v1 template name so the delegate view resolves correctly.
  def render("get_block_number_by_time.json", assigns) do
    V1BlockView.render("getblocknobytime.json", assigns)
  end

  defdelegate render(template, assigns), to: V1BlockView
end
