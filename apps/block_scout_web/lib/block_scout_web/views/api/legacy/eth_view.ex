# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.Legacy.EthView do
  @moduledoc false
  defdelegate render(template, assigns), to: BlockScoutWeb.API.EthRPC.View
end
