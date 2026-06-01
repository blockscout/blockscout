# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthSendRawTransactionResult do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :string,
    pattern: General.full_hash_pattern(),
    description: "Hash of the submitted transaction — 32 bytes, hex-encoded.",
    example: "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331e"
  })
end
