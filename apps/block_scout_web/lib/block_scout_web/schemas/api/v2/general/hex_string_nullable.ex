defmodule BlockScoutWeb.Schemas.API.V2.General.HexStringNullable do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.hex_string_pattern(), nullable: true})
end
