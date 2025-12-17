defmodule BlockScoutWeb.Schemas.API.V2.General.MethodNameNullable do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :string,
    nullable: true,
    example: "transfer",
    description: "Method name or hex method id"
  })
end
