defmodule BlockScoutWeb.Schemas.API.V2.General.FloatStringNullable do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.float_pattern(), nullable: true})
end
