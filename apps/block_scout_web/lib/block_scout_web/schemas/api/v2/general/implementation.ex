# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.General.Implementation do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.General.Implementation.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      description: "Proxy smart contract implementation",
      type: :object,
      properties: %{
        address_hash: General.AddressHash,
        name: %Schema{type: :string, nullable: true}
      },
      # `name` is omitted for conflicting proxy implementations (see
      # `Explorer.Chain.SmartContract.Proxy.conflicting_implementations_info/1`),
      # so only `address_hash` is required.
      required: [:address_hash],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
