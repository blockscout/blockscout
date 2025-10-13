defmodule BlockScoutWeb.Schemas.API.V2.General.NullString do
  @moduledoc false
  require OpenApiSpex
  OpenApiSpex.schema(%{type: :string, pattern: ~r"^null$"})
end
