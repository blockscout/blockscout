# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetStorageAtResult do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :string,
    pattern: General.full_hash_pattern(),
    description: "Hex-encoded 32-byte storage value at the requested slot."
  })
end
