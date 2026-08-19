# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch.DataContainer do
  @moduledoc """
  Reusable enum describing where an Optimism batch's data is stored.

  Kept in sync with `Explorer.Chain.Optimism.FrameSequenceBlob.filter_blobs_by_type/1`
  (the `:in_blob4844`/`:in_celestia`/`:in_eigenda`/`:in_alt_da`/`:in_calldata` tags).
  Exposed as a standalone component (`OptimismBatchDataContainer`) so the value set
  can be referenced directly from client code.
  """
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "OptimismBatchDataContainer",
    type: :string,
    enum: ["in_blob4844", "in_celestia", "in_eigenda", "in_alt_da", "in_calldata"],
    nullable: false,
    description: "Designates where the batch data is stored."
  })
end
