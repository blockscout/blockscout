defmodule BlockScoutWeb.Schemas.API.V2.AddressNullable do
  @moduledoc """
  This module defines the schema for nullable address struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Address.schema()
    |> Helper.extend_schema(
      title: "AddressNullable",
      description: "AddressNullable",
      nullable: true
    )
  )
end
