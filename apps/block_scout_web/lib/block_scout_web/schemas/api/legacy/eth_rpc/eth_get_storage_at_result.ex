# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetStorageAtResult do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]*$/,
    description: "Hex-encoded storage value at the requested slot — typically a 32-byte word."
  })
end
