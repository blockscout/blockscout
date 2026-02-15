defmodule BlockScoutWeb.Schemas.API.V2.Account.User do
  @moduledoc """
  This module defines the schema for the user.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General.AddressHashNullable
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      email: %Schema{type: :string, format: :email, nullable: true},
      name: %Schema{type: :string, nullable: true},
      nickname: %Schema{type: :string, nullable: true},
      avatar: %Schema{type: :string, format: :uri, nullable: true},
      address_hash: AddressHashNullable
    },
    required: [:email, :name, :nickname, :avatar, :address_hash],
    additionalProperties: false
  })
end
