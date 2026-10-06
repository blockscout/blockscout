# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.ZkSync.ConfirmedBatchListItem do
  @moduledoc """
  Schema for a ZkSync batch item in the main-page confirmed-only list.

  Extends `ZkSync.BatchListItem` and narrows `status` to the three values
  reachable when the database query filters out batches without a commit
  transaction (see `Explorer.Chain.ZkSync.Reader.batches/1` with `confirmed?: true`).
  """
  require OpenApiSpex

  alias BlockScoutWeb.API.V2.ZkSyncView
  alias BlockScoutWeb.Schemas.API.V2.ZkSync.BatchListItem
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  # Reachable when `Reader.batches(confirmed?: true)` restricts results to batches
  # with a non-null `commit_id`: the `lifecycle_status/1` cascade in `ZkSyncView`
  # cannot fall through to `"Sealed on L2"`.
  @confirmed_status_enum ZkSyncView.batch_lifecycle_status_enum() -- ["Sealed on L2"]

  OpenApiSpex.schema(
    BatchListItem.schema()
    |> Helper.extend_schema(
      title: "ZkSync.ConfirmedBatchListItem",
      description:
        "ZkSync rollup batch summary for the main-page confirmed list. " <>
          "Only batches with an observed commit transaction are included, so " <>
          "`status` excludes the `Sealed on L2` value of the full batch lifecycle.",
      properties: %{
        status: %Schema{
          type: :string,
          enum: @confirmed_status_enum,
          description: """
          Lifecycle status of the batch:
          * `Sent to L1` - Commit transaction has been submitted on the parent chain.
          * `Validated on L1` - Prove transaction has been submitted on the parent chain.
          * `Executed on L1` - Execute transaction has been submitted on the parent chain.
          """
        }
      }
    )
  )
end
