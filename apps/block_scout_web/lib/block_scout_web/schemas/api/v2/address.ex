defmodule BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.Helper
  alias Ecto.Enum, as: EctoEnum
  alias Explorer.Chain.Address
  alias OpenApiSpex.Schema

  @filecoin_robust_address_schema %Schema{
    type: :string,
    description: "Robust f0/f1/f2/f3/f4 Filecoin address",
    example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
    nullable: true
  }

  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        schema
        |> Helper.extend_schema(
          properties: %{
            filecoin: %Schema{
              type: :object,
              properties: %{
                id: %Schema{
                  type: :string,
                  description: "Short f0 Filecoin address that may change during chain reorgs",
                  example: "f03248220",
                  nullable: true
                },
                robust: @filecoin_robust_address_schema,
                actor_type: %Schema{
                  type: :string,
                  description: "Type of actor associated with the Filecoin address",
                  enum: EctoEnum.values(Address, :filecoin_actor_type),
                  nullable: true
                }
              },
              required: [:id, :robust, :actor_type],
              additionalProperties: false
            }
          }
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Address do
  @moduledoc """
  This module defines the schema for address struct, returned by BlockScoutWeb.API.V2.Helper.address_with_info/5.

  Note that BlockScoutWeb.Schemas.API.V2.Address.Response is defined in __after_compile__/2 callback. This is done to reuse the Address schema in the AddressResponse schema.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.{General, Proxy}
  alias Explorer.Chain.Address.Reputation
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Address",
      type: :object,
      properties: %{
        hash: General.AddressHash,
        is_contract: %Schema{type: :boolean, description: "Has address contract code?", nullable: true},
        name: %Schema{type: :string, description: "Name associated with the address", nullable: true},
        is_scam: %Schema{type: :boolean, description: "Has address scam badge?", nullable: false},
        reputation: %Schema{
          type: :string,
          enum: Reputation.enum_values(),
          description: "Reputation of the address",
          nullable: false
        },
        proxy_type: General.ProxyType,
        implementations: %Schema{
          description: "Implementations linked with the contract",
          type: :array,
          items: General.Implementation
        },
        is_verified: %Schema{type: :boolean, description: "Has address associated source code?", nullable: true},
        ens_domain_name: %Schema{
          type: :string,
          description: "ENS domain name associated with the address",
          nullable: true
        },
        metadata: %Schema{allOf: [Proxy.Metadata], nullable: true},
        private_tags: %Schema{
          description: "Private tags associated with the address",
          type: :array,
          items: General.Tag
        },
        watchlist_names: %Schema{
          description: "Watchlist name associated with the address",
          type: :array,
          items: General.WatchlistName
        },
        public_tags: %Schema{
          description: "Public tags associated with the address",
          type: :array,
          items: General.Tag
        }
      },
      required: [
        :hash,
        :is_contract,
        :name,
        :is_scam,
        :reputation,
        :proxy_type,
        :implementations,
        :is_verified,
        :ens_domain_name,
        :metadata
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
