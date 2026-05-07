defmodule BlockScoutWeb.API.Legacy.LogsView do
  @moduledoc false
  defdelegate render(template, assigns), to: BlockScoutWeb.API.RPC.LogsView
end
