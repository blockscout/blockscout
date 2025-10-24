defmodule BlockScoutWeb.Schemas.API.V2.General.EmptyString do
  @moduledoc false
  require OpenApiSpex
  OpenApiSpex.schema(%{type: :string, minLength: 0, maxLength: 0})
end
