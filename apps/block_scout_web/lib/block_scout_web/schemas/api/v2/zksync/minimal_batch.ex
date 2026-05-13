# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.ZkSync.MinimalBatch do
  @moduledoc """
  Shared base schema for ZkSync batch responses.

  Holds the properties common to both the detailed batch view (`ZkSync.Batch`)
  and the batch-list item view (`ZkSync.BatchListItem`): batch identifier,
  sealing timestamp, lifecycle status, and the three optional parent-chain
  lifecycle transactions (commit / prove / execute).
  """
  require OpenApiSpex

  alias BlockScoutWeb.API.V2.ZkSyncView
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ZkSync.MinimalBatch",
    description: "Common ZkSync rollup batch properties shared by list and detail responses.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, minimum: 0, description: "Batch number on the rollup."},
      timestamp:
        Helper.extend_schema(General.Timestamp.schema(),
          description: "Timestamp when the batch was sealed on the rollup."
        ),
      status: %Schema{
        type: :string,
        enum: ZkSyncView.batch_lifecycle_status_enum(),
        description: """
        Lifecycle status of the batch:
        * `Sealed on L2` - Batch is finalized on the rollup and no parent-chain lifecycle transaction has been observed yet.
        * `Sent to L1` - Commit transaction has been submitted on the parent chain.
        * `Validated on L1` - Prove transaction has been submitted on the parent chain.
        * `Executed on L1` - Execute transaction has been submitted on the parent chain.
        """
      },
      commit_transaction_hash:
        Helper.extend_schema(General.FullHashNullable.schema(),
          description:
            "Hash of the parent-chain transaction that committed this batch. " <>
              "`null` until the commit transaction is observed."
        ),
      commit_transaction_timestamp:
        Helper.extend_schema(General.TimestampNullable.schema(),
          description:
            "Timestamp of the parent-chain transaction that committed this batch. " <>
              "`null` until the commit transaction is observed."
        ),
      prove_transaction_hash:
        Helper.extend_schema(General.FullHashNullable.schema(),
          description:
            "Hash of the parent-chain transaction that proved this batch. " <>
              "`null` until the prove transaction is observed."
        ),
      prove_transaction_timestamp:
        Helper.extend_schema(General.TimestampNullable.schema(),
          description:
            "Timestamp of the parent-chain transaction that proved this batch. " <>
              "`null` until the prove transaction is observed."
        ),
      execute_transaction_hash:
        Helper.extend_schema(General.FullHashNullable.schema(),
          description:
            "Hash of the parent-chain transaction that executed this batch. " <>
              "`null` until the execute transaction is observed."
        ),
      execute_transaction_timestamp:
        Helper.extend_schema(General.TimestampNullable.schema(),
          description:
            "Timestamp of the parent-chain transaction that executed this batch. " <>
              "`null` until the execute transaction is observed."
        )
    },
    required: [
      :number,
      :timestamp,
      :status,
      :commit_transaction_hash,
      :commit_transaction_timestamp,
      :prove_transaction_hash,
      :prove_transaction_timestamp,
      :execute_transaction_hash,
      :execute_transaction_timestamp
    ],
    additionalProperties: false
  })
end
