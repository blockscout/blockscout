# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthSendRawTransactionResult do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]{64}$/,
    description: "Hash of the submitted transaction — 32 bytes, hex-encoded.",
    example: "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331e"
  })
end
