defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.Batch do
  @moduledoc """
  Schema for a detailed Arbitrum batch response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.CommitmentTransaction
  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.DataAvailability
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Detailed Arbitrum batch info.",
    type: :object,
    properties: %{
      number: %Schema{
        type: :integer,
        minimum: 0,
        description: "Sequential identifier assigned to this batch by the sequencer."
      },
      transactions_count: %Schema{type: :integer, minimum: 0, description: "Number of transactions in the batch."},
      start_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "First Rollup block included in the batch."
      },
      end_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "Last Rollup block included in the batch."
      },
      before_acc_hash: %Schema{
        allOf: [General.FullHash],
        description:
          "Accumulator hash of the sequencer inbox before this batch was appended. " <>
            "Forms a hash chain: must equal `after_acc_hash` of the previous batch."
      },
      after_acc_hash: %Schema{
        allOf: [General.FullHash],
        description:
          "Accumulator hash of the sequencer inbox after this batch was appended. " <>
            "Must equal `before_acc_hash` of the next batch."
      },
      commitment_transaction: CommitmentTransaction,
      data_availability: %Schema{
        oneOf: [
          DataAvailability.Base,
          DataAvailability.Anytrust,
          DataAvailability.Celestia,
          DataAvailability.Eigenda
        ],
        description: "Data availability information. Structure varies by `batch_data_container` type."
      }
    },
    required: [
      :number,
      :transactions_count,
      :start_block_number,
      :end_block_number,
      :before_acc_hash,
      :after_acc_hash,
      :commitment_transaction,
      :data_availability
    ],
    additionalProperties: false
  })
end
