defmodule BlockScoutWeb.Schemas.API.V2.General.IntegerString do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.integer_pattern(), nullable: false})
end
