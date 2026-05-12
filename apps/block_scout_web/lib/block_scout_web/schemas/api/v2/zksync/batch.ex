# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.ZkSync.Batch do
  @moduledoc """
  This module defines the schema for the ZkSync Batch struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ZkSync.Batch",
    description:
      "ZkSync rollup batch - a group of rollup blocks settled together on the parent chain - " <>
        "with the corresponding parent-chain lifecycle data.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, minimum: 0, description: "Batch number on the rollup."},
      timestamp:
        Helper.extend_schema(General.Timestamp.schema(),
          description: "Timestamp when the batch was sealed on the rollup."
        ),
      root_hash:
        Helper.extend_schema(General.FullHash.schema(),
          description: "State root hash committed for this batch on the parent chain."
        ),
      l1_transactions_count: %Schema{
        type: :integer,
        minimum: 0,
        description: "Number of transactions in the batch originating on the parent chain."
      },
      l2_transactions_count: %Schema{
        type: :integer,
        minimum: 0,
        description: "Number of transactions in the batch originating on the rollup."
      },
      l1_gas_price:
        Helper.extend_schema(General.NonNegativeIntegerString.schema(),
          description: "Parent-chain gas price observed for this batch, in wei."
        ),
      l2_fair_gas_price:
        Helper.extend_schema(General.NonNegativeIntegerString.schema(),
          description: "Rollup fair gas price for this batch, in wei."
        ),
      start_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "First rollup block included in the batch."
      },
      end_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "Last rollup block included in the batch."
      },
      # Enum values must be kept in sync with BlockScoutWeb.API.V2.ZkSyncView.batch_status_enum/0.
      status: %Schema{
        type: :string,
        enum: ["Executed on L1", "Validated on L1", "Sent to L1", "Sealed on L2", "Processed on L2"],
        description: """
        Lifecycle status of the batch:
        * `Processed on L2` - Batch has been processed on the rollup but is not yet sealed.
        * `Sealed on L2` - Batch is finalized on the rollup but no parent-chain lifecycle transaction has been observed yet.
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
      :root_hash,
      :l1_transactions_count,
      :l2_transactions_count,
      :l1_gas_price,
      :l2_fair_gas_price,
      :start_block_number,
      :end_block_number,
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
