# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthCallResult do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :string,
    pattern: General.hex_data_pattern(),
    description: "Hex-encoded return data from the executed call. May be `0x` if the call returned no data."
  })
end
