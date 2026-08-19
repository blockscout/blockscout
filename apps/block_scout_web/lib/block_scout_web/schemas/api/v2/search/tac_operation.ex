# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Search.TacOperation do
  @moduledoc """
  This module defines the schema for a TAC operation in the search results.

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
    title: "TacOperationSearchResult",
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
