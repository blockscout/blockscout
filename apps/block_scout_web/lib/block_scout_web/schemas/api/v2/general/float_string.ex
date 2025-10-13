defmodule BlockScoutWeb.Schemas.API.V2.General.FloatString do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.float_pattern()})
end
