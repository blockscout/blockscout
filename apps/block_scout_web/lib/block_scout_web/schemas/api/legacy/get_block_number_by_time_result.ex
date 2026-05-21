# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.GetBlockNumberByTimeResult do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      blockNumber: Helper.describe_inline(General.IntegerString.schema(), "Decimal-string block number.")
    },
    required: [:blockNumber],
    additionalProperties: false,
    nullable: true
  })
end
