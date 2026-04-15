defmodule BlockScoutWeb.API.V2.Legacy.LogsView do
  @moduledoc false
  defdelegate render(template, assigns), to: BlockScoutWeb.API.RPC.LogsView
end
