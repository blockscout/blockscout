# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  import BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations, only: [filecoin_robust_address_schema: 0]

  alias BlockScoutWeb.Schemas.Helper

  # On Filecoin, every address-bearing search result gets a `filecoin_robust_address`
  # field (see `FilecoinView.preload_and_put_filecoin_robust_address_to_search_results/1`).
  def address_chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        Helper.extend_schema(schema,
          properties: %{filecoin_robust_address: filecoin_robust_address_schema()},
          required: [:filecoin_robust_address]
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.EnsInfo do
  @moduledoc """
  ENS info attached to address-type search results (`BENS.get_address/1`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultEnsInfo",
    type: :object,
    properties: %{
      name: %Schema{type: :string, nullable: false, description: "Resolved ENS domain name."},
      expiry_date: %Schema{type: :string, nullable: true, description: "Domain expiry date."},
      names_count: %Schema{type: :integer, nullable: false, minimum: 0},
      address_hash: General.AddressHash,
      # Opaque protocol metadata; present only for ens_domain results (BENS multiprotocol).
      protocol: %Schema{nullable: true, description: "ENS protocol metadata."},
      protocol_dapp_url: %Schema{type: :string, nullable: true},
      protocol_dapp_logo: %Schema{type: :string, nullable: true}
    },
    required: [:name, :expiry_date, :names_count, :address_hash, :protocol_dapp_url, :protocol_dapp_logo],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Token do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Search.Result.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "SearchResultToken",
      type: :object,
      properties: %{
        type: %Schema{type: :string, enum: ["token"], nullable: false},
        name: %Schema{type: :string, nullable: true},
        symbol: %Schema{type: :string, nullable: true},
        address_hash: General.AddressHash,
        token_url: %Schema{type: :string, nullable: false},
        address_url: %Schema{type: :string, nullable: false},
        icon_url: %Schema{type: :string, nullable: true},
        token_type: %Schema{type: :string, nullable: true},
        is_smart_contract_verified: %Schema{type: :boolean, nullable: true},
        exchange_rate: General.FloatStringNullable,
        total_supply: General.IntegerStringNullable,
        circulating_market_cap: General.FloatStringNullable,
        is_verified_via_admin_panel: %Schema{type: :boolean, nullable: true},
        certified: %Schema{type: :boolean, nullable: false},
        priority: %Schema{type: :integer, nullable: false},
        reputation: %Schema{type: :string, enum: ["ok", "scam"], nullable: false},
        is_smart_contract_address: %Schema{type: :boolean, nullable: true}
      },
      required: [
        :type,
        :name,
        :symbol,
        :address_hash,
        :token_url,
        :address_url,
        :icon_url,
        :token_type,
        :is_smart_contract_verified,
        :exchange_rate,
        :total_supply,
        :circulating_market_cap,
        :is_verified_via_admin_panel,
        :certified,
        :priority,
        :reputation,
        :is_smart_contract_address
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.AddressOrContract do
  @moduledoc """
  Search result for an address or smart contract (these share one shape,
  distinguished by `type`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Search.Result.{ChainTypeCustomizations, EnsInfo}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "SearchResultAddressOrContract",
      type: :object,
      properties: %{
        type: %Schema{type: :string, enum: ["address", "contract"], nullable: false},
        name: %Schema{type: :string, nullable: true},
        address_hash: General.AddressHash,
        url: %Schema{type: :string, nullable: false},
        is_smart_contract_verified: %Schema{type: :boolean, nullable: true},
        ens_info: %Schema{allOf: [EnsInfo], nullable: true},
        certified: %Schema{type: :boolean, nullable: false},
        priority: %Schema{type: :integer, nullable: false},
        reputation: %Schema{type: :string, enum: ["ok", "scam"], nullable: false},
        is_smart_contract_address: %Schema{type: :boolean, nullable: true}
      },
      required: [
        :type,
        :name,
        :address_hash,
        :url,
        :is_smart_contract_verified,
        :ens_info,
        :certified,
        :priority,
        :reputation,
        :is_smart_contract_address
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Label do
  @moduledoc """
  Search result for an address label (public/private tag). `name` (the label's
  display name) and `address_hash` are always present.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Search.Result.{ChainTypeCustomizations, EnsInfo}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "SearchResultLabel",
      type: :object,
      properties: %{
        type: %Schema{type: :string, enum: ["label"], nullable: false},
        name: %Schema{type: :string, nullable: false},
        address_hash: General.AddressHash,
        url: %Schema{type: :string, nullable: false},
        is_smart_contract_verified: %Schema{type: :boolean, nullable: true},
        ens_info: %Schema{allOf: [EnsInfo], nullable: true},
        certified: %Schema{type: :boolean, nullable: false},
        priority: %Schema{type: :integer, nullable: false},
        reputation: %Schema{type: :string, enum: ["ok", "scam"], nullable: false},
        is_smart_contract_address: %Schema{type: :boolean, nullable: true}
      },
      required: [
        :type,
        :name,
        :address_hash,
        :url,
        :is_smart_contract_verified,
        :ens_info,
        :certified,
        :priority,
        :reputation,
        :is_smart_contract_address
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.EnsDomain do
  @moduledoc """
  Search result for an ENS domain. `ens_info` is always present; `address_hash`
  (and the derived `url`) are `null` when the domain does not resolve to an address.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Search.Result.{ChainTypeCustomizations, EnsInfo}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "SearchResultEnsDomain",
      type: :object,
      properties: %{
        type: %Schema{type: :string, enum: ["ens_domain"], nullable: false},
        name: %Schema{type: :string, nullable: true},
        address_hash: General.AddressHashNullable,
        url: %Schema{type: :string, nullable: true},
        is_smart_contract_verified: %Schema{type: :boolean, nullable: true},
        ens_info: EnsInfo,
        certified: %Schema{type: :boolean, nullable: false},
        priority: %Schema{type: :integer, nullable: false},
        reputation: %Schema{type: :string, enum: ["ok", "scam"], nullable: false},
        is_smart_contract_address: %Schema{type: :boolean, nullable: true}
      },
      required: [
        :type,
        :name,
        :address_hash,
        :url,
        :is_smart_contract_verified,
        :ens_info,
        :certified,
        :priority,
        :reputation,
        :is_smart_contract_address
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.MetadataTag do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Proxy
  alias BlockScoutWeb.Schemas.API.V2.Search.Result.{ChainTypeCustomizations, EnsInfo}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "SearchResultMetadataTag",
      type: :object,
      properties: %{
        type: %Schema{type: :string, enum: ["metadata_tag"], nullable: false},
        name: %Schema{type: :string, nullable: true},
        address_hash: General.AddressHash,
        url: %Schema{type: :string, nullable: false},
        is_smart_contract_verified: %Schema{type: :boolean, nullable: true},
        ens_info: %Schema{allOf: [EnsInfo], nullable: true},
        certified: %Schema{type: :boolean, nullable: false},
        priority: %Schema{type: :integer, nullable: false},
        metadata: Proxy.MetadataTag,
        reputation: %Schema{type: :string, enum: ["ok", "scam"], nullable: false},
        is_smart_contract_address: %Schema{type: :boolean, nullable: true}
      },
      required: [
        :type,
        :name,
        :address_hash,
        :url,
        :is_smart_contract_verified,
        :ens_info,
        :certified,
        :priority,
        :metadata,
        :reputation,
        :is_smart_contract_address
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.address_chain_type_fields()
  )
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Block do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultBlock",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["block"], nullable: false},
      block_number: %Schema{type: :integer, nullable: false, minimum: 0},
      block_hash: General.FullHash,
      url: %Schema{type: :string, nullable: false},
      timestamp: General.Timestamp,
      block_type: %Schema{type: :string, nullable: false},
      priority: %Schema{type: :integer, nullable: false}
    },
    required: [:type, :block_number, :block_hash, :url, :timestamp, :block_type, :priority],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Transaction do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultTransaction",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["transaction"], nullable: false},
      transaction_hash: General.FullHash,
      url: %Schema{type: :string, nullable: false},
      timestamp: General.TimestampNullable,
      priority: %Schema{type: :integer, nullable: false}
    },
    required: [:type, :transaction_hash, :url, :timestamp, :priority],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.UserOperation do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultUserOperation",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["user_operation"], nullable: false},
      user_operation_hash: General.FullHash,
      timestamp: General.TimestampNullable,
      priority: %Schema{type: :integer, nullable: false}
    },
    required: [:type, :user_operation_hash, :timestamp, :priority],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Blob do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultBlob",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["blob"], nullable: false},
      blob_hash: General.FullHash,
      timestamp: General.TimestampNullable,
      priority: %Schema{type: :integer, nullable: false}
    },
    required: [:type, :blob_hash, :timestamp, :priority],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.TacOperation.Operation do
  @moduledoc """
  This module defines the schema for the operation object nested in a TAC operation search
  result.

  The object is returned by the `tac-operation-lifecycle` microservice (Read API v2) and is
  proxied verbatim, so this schema mirrors the microservice contract rather than describing a
  Blockscout-owned struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  @type_enum [
    "UNKNOWN",
    "TON_TAC_TON",
    "TAC_TON",
    "TON_TAC"
  ]

  @status_enum [
    "pending",
    "success",
    "failed"
  ]

  @blockchain_enum [
    "TAC",
    "TON",
    "UNKNOWN_BLOCKCHAIN"
  ]

  @sender_schema %Schema{
    type: :object,
    properties: %{
      address: %Schema{
        type: :string,
        nullable: false,
        description: "TAC (EVM) or TON address, depending on `blockchain`",
        example: "EQDoF2OkxsI3gc5jAuxlqozN9H/SgEOUCopMa1yU4djLaXuL"
      },
      blockchain: %Schema{type: :string, enum: @blockchain_enum, nullable: false, example: "TON"}
    },
    required: [:address, :blockchain],
    additionalProperties: false,
    nullable: true
  }

  OpenApiSpex.schema(%{
    title: "TacOperation",
    description: "TAC operation as returned by the tac-operation-lifecycle service Read API v2.",
    type: :object,
    properties: %{
      operation_id: %Schema{
        type: :string,
        nullable: false,
        example: "0xf01646ac36cbbcebd8a5ff09c300d5f3bebdd2fbe0135a377eaa485d9edcc670"
      },
      type: %Schema{
        type: :string,
        enum: @type_enum,
        nullable: false,
        description: "Transfer route. Never carries a lifecycle outcome — see `status` and `rollback`.",
        example: "TAC_TON"
      },
      status: %Schema{
        type: :string,
        enum: @status_enum,
        nullable: false,
        description: "Business outcome of the operation.",
        example: "success"
      },
      rollback: %Schema{
        type: :boolean,
        nullable: false,
        description: "Whether a rollback occurred.",
        example: false
      },
      timestamp: General.Timestamp,
      sender: @sender_schema,
      error_reason: %Schema{
        type: :string,
        nullable: true,
        description:
          "Short failure label. It is published only when the stored reason is short enough to be a label, so it is legitimately `null` on a failed operation — its absence does not imply success.",
        example: "Insufficient Fee"
      }
    },
    required: [:operation_id, :type, :status, :rollback, :timestamp],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.TacOperation do
  @moduledoc """
  Search result for a TAC operation. `tac_operation` is the operation object
  returned by the external TAC microservice (Read API v2).
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Search.Result
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "SearchResultTacOperation",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["tac_operation"], nullable: false},
      tac_operation: Result.TacOperation.Operation,
      priority: %Schema{type: :integer, nullable: false}
    },
    required: [:type, :tac_operation, :priority],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Search.Result.Item do
  @moduledoc """
  A single search result item. Discriminated union on `type`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Search.Result

  OpenApiSpex.schema(%{
    title: "SearchResultItem",
    type: :object,
    oneOf: [
      Result.Token,
      Result.AddressOrContract,
      Result.Label,
      Result.EnsDomain,
      Result.MetadataTag,
      Result.Block,
      Result.Transaction,
      Result.UserOperation,
      Result.Blob,
      Result.TacOperation
    ],
    discriminator: %OpenApiSpex.Discriminator{
      propertyName: "type",
      mapping: %{
        "token" => "#/components/schemas/SearchResultToken",
        "address" => "#/components/schemas/SearchResultAddressOrContract",
        "contract" => "#/components/schemas/SearchResultAddressOrContract",
        "label" => "#/components/schemas/SearchResultLabel",
        "ens_domain" => "#/components/schemas/SearchResultEnsDomain",
        "metadata_tag" => "#/components/schemas/SearchResultMetadataTag",
        "block" => "#/components/schemas/SearchResultBlock",
        "transaction" => "#/components/schemas/SearchResultTransaction",
        "user_operation" => "#/components/schemas/SearchResultUserOperation",
        "blob" => "#/components/schemas/SearchResultBlob",
        "tac_operation" => "#/components/schemas/SearchResultTacOperation"
      }
    }
  })
end
