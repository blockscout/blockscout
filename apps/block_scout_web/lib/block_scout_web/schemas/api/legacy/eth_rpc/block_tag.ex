# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.BlockTag do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    description:
      "Block parameter: a hex-encoded block number (`0x` prefix) or one of the " <>
        "tags `latest`, `earliest`, `pending`.",
    anyOf: [
      %OpenApiSpex.Schema{type: :string, pattern: ~r/^0x[0-9a-fA-F]+$/},
      %OpenApiSpex.Schema{type: :string, enum: ["latest", "earliest", "pending"]}
    ]
  })
end
