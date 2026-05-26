# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthCallResult do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]*$/,
    description: "Hex-encoded return data from the executed call. May be `0x` if the call returned no data."
  })
end
