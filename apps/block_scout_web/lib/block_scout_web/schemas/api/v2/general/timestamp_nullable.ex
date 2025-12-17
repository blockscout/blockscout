defmodule BlockScoutWeb.Schemas.API.V2.General.TimestampNullable do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    format: :"date-time",
    nullable: true
  })
end
