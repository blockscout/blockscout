defmodule BlockScoutWeb.Schemas.API.V2.General.Tag do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Address tag struct",
    type: :object,
    properties: %{
      address_hash: General.AddressHash,
      display_name: %Schema{type: :string, nullable: false},
      label: %Schema{type: :string, nullable: false}
    },
    required: [:address_hash, :display_name, :label],
    additionalProperties: false
  })
end
