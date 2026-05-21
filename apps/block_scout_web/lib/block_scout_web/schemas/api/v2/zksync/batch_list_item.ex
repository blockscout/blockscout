# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.ZkSync.BatchListItem do
  @moduledoc """
  Schema for a ZkSync batch item in list responses.

  Extends `ZkSync.MinimalBatch` with `transactions_count` — the aggregate of
  parent-chain and rollup-originated transactions in the batch.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.ZkSync.MinimalBatch
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    MinimalBatch.schema()
    |> Helper.extend_schema(
      title: "ZkSync.BatchListItem",
      description: "ZkSync rollup batch summary for list endpoints.",
      properties: %{
        transactions_count: %Schema{
          type: :integer,
          minimum: 0,
          description: "Total number of transactions in the batch (parent-chain originated plus rollup originated)."
        }
      },
      required: [:transactions_count]
    )
  )
end
