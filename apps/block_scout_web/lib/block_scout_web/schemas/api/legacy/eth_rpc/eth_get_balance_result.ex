# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetBalanceResult do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]+$/,
    description: "Hex-encoded account balance in wei. Always at least one digit (`0x0` for zero)."
  })
end
