defmodule BlockScoutWeb.Schemas.API.V2.General.IntegerStringNullable do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.integer_pattern(), nullable: true})
end
