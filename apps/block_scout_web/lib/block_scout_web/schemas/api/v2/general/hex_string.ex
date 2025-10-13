defmodule BlockScoutWeb.Schemas.API.V2.General.HexString do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.hex_string_pattern(), nullable: false})
end
