# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Eden.Call do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :object,
    nullable: false,
    properties: %{
      to: General.AddressHashNullable,
      value: General.IntegerString,
      input: General.HexString
    },
    required: [:to, :value, :input],
    additionalProperties: false
  })
end
