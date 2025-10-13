defmodule BlockScoutWeb.Schemas.API.V2.General.FullHash do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  OpenApiSpex.schema(%{type: :string, pattern: General.full_hash_pattern(), nullable: false})
end
