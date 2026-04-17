defmodule BlockScoutWeb.Schemas.API.V2.Account.Session do
  @moduledoc """
  This module defines the schema for the account session.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General.AddressHashNullable
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, minimum: 0, nullable: false},
      uid: %Schema{type: :string, nullable: false},
      email: %Schema{type: :string, format: :email, nullable: true},
      name: %Schema{type: :string, nullable: true},
      nickname: %Schema{type: :string, nullable: true},
      avatar: %Schema{type: :string, format: :uri, nullable: true},
      address_hash: AddressHashNullable,
      watchlist_id: %Schema{type: :integer, minimum: 0, nullable: false},
      email_verified: %Schema{type: :boolean, nullable: false}
    },
    required: [:id, :uid, :email, :nickname, :avatar, :address_hash, :email_verified],
    additionalProperties: false
  })
end
