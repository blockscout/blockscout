defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.BatchForList do
  @moduledoc """
  Schema for an Arbitrum batch item in list responses.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.{BatchDataContainer, CommitmentTransaction}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Arbitrum batch summary for list endpoints.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, minimum: 0, description: "Batch number."},
      transactions_count: %Schema{type: :integer, minimum: 0, description: "Number of transactions in the batch."},
      blocks_count: %Schema{type: :integer, minimum: 0, description: "Number of blocks included in the batch."},
      batch_data_container: BatchDataContainer,
      commitment_transaction: CommitmentTransaction
    },
    required: [:number, :transactions_count, :blocks_count, :batch_data_container, :commitment_transaction],
    additionalProperties: false
  })
end
