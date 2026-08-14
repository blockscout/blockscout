# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.PreviewAddress do
  @moduledoc """
  Lightweight address representation used in the transaction preview endpoint.
  Contains only the hash, display name, ENS domain name, and metadata tags.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Proxy}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Lightweight address in transaction preview",
    type: :object,
    nullable: true,
    properties: %{
      hash: General.AddressHash,
      name: %Schema{
        type: :string,
        description: "Display name of the address (contract name or address name)",
        nullable: true
      },
      ens_domain_name: %Schema{
        type: :string,
        description: "ENS domain name associated with the address. Populated only when preload_ens=true is passed.",
        nullable: true
      },
      metadata: %Schema{
        allOf: [Proxy.Metadata],
        description:
          "Address metadata tags from the Metadata microservice. Populated only when preload_metadata=true is passed.",
        nullable: true
      }
    },
    required: [:hash, :name, :ens_domain_name, :metadata],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Preview do
  @moduledoc """
  Schema for the lightweight transaction preview response returned by
  `GET /api/v2/transactions/:transaction_hash/preview`.

  Used for rendering OG/social-media previews with minimal data.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Transaction.PreviewAddress
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Lightweight transaction preview for social media embeds",
    type: :object,
    properties: %{
      status: %Schema{
        type: :string,
        enum: ["ok", "error"],
        nullable: true,
        description: "Transaction execution status"
      },
      timestamp: General.TimestampNullable,
      method: General.MethodNameNullable,
      from: %Schema{allOf: [PreviewAddress], nullable: true},
      to: %Schema{allOf: [PreviewAddress], nullable: true}
    },
    required: [:status, :timestamp, :method, :from, :to],
    additionalProperties: false
  })
end
