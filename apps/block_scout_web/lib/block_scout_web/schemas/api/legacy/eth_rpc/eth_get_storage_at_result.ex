# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetStorageAtResult do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]{64}$/,
    description: "Hex-encoded 32-byte storage value at the requested slot."
  })
end
