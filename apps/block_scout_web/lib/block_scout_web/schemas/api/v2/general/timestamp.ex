defmodule BlockScoutWeb.Schemas.API.V2.General.Timestamp do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    format: :"date-time",
    nullable: false
  })
end
