# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.BlockTag do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    description:
      "Block parameter: a hex-encoded block number (`0x` prefix) or one of the " <>
        "tags `latest`, `earliest`, `pending`.",
    anyOf: [
      %OpenApiSpex.Schema{type: :string, pattern: General.hex_quantity_pattern()},
      %OpenApiSpex.Schema{type: :string, enum: ["latest", "earliest", "pending"]}
    ]
  })
end
