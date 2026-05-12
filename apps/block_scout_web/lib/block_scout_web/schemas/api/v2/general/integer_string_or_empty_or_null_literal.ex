# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.General.IntegerStringOrEmptyOrNullLiteral do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    oneOf: [
      %Schema{type: :string, pattern: General.non_negative_integer_pattern()},
      %Schema{type: :string, enum: ["", "null"]}
    ]
  })
end
