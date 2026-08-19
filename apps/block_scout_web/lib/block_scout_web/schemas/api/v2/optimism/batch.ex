# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.Batch do
  @moduledoc """
  This module defines the schema for the Optimism Batch struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Optimism.Batch.DataContainer
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OptimismBatch",
    description: "Optimism Batch struct.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer},
      transactions_count: %Schema{type: :integer},
      l1_timestamp: General.Timestamp,
      l1_transaction_hashes: %Schema{
        type: :array,
        items: General.FullHash,
        nullable: false
      },
      batch_data_container: %Schema{allOf: [DataContainer], nullable: true},
      l2_end_block_number: %Schema{type: :integer},
      l2_start_block_number: %Schema{type: :integer}
    },
    required: [
      :number,
      :transactions_count,
      :l1_timestamp,
      :l1_transaction_hashes,
      :batch_data_container,
      :l2_end_block_number,
      :l2_start_block_number
    ],
    additionalProperties: false
  })
end
