# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.ZkSync.Batch do
  @moduledoc """
  Schema for the detailed ZkSync batch response.

  Extends `ZkSync.MinimalBatch` with rollup-block range, state root, the two
  transaction counts (parent-chain originated and rollup originated), and the
  gas prices observed for this batch.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.ZkSync.MinimalBatch
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    MinimalBatch.schema()
    |> Helper.extend_schema(
      title: "ZkSync.Batch",
      description:
        "ZkSync rollup batch - a group of rollup blocks settled together on the parent chain - " <>
          "with the corresponding parent-chain lifecycle data.",
      properties: %{
        root_hash:
          Helper.describe_inline(
            General.FullHash.schema(),
            "State root hash committed for this batch on the parent chain."
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
          Helper.describe_inline(
            General.NonNegativeIntegerString.schema(),
            "Parent-chain gas price observed for this batch, in wei."
          ),
        l2_fair_gas_price:
          Helper.describe_inline(
            General.NonNegativeIntegerString.schema(),
            "Rollup fair gas price for this batch, in wei."
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
        }
      },
      required: [
        :root_hash,
        :l1_transactions_count,
        :l2_transactions_count,
        :l1_gas_price,
        :l2_fair_gas_price,
        :start_block_number,
        :end_block_number
      ]
    )
  )
end
