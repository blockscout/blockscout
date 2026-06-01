# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetBalanceResult do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :string,
    pattern: General.hex_quantity_pattern(),
    description: "Hex-encoded account balance in wei. Always at least one digit (`0x0` for zero)."
  })
end
