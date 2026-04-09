defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.Batch do
  @moduledoc """
  Schema for a detailed Arbitrum batch response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Arbitrum.{BatchDataContainer, CommitmentTransaction}
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Detailed Arbitrum batch info.",
    type: :object,
    properties: %{
      number: %Schema{type: :integer, minimum: 0, description: "Batch number."},
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
      before_acc_hash: General.FullHash,
      after_acc_hash: General.FullHash,
      commitment_transaction: CommitmentTransaction,
      data_availability: %Schema{
        oneOf: [
          # Variant: nil / in_blob4844 / in_calldata (no extra fields)
          %Schema{
            type: :object,
            properties: %{batch_data_container: BatchDataContainer},
            required: [:batch_data_container],
            additionalProperties: false
          },
          # Variant: in_anytrust
          %Schema{
            type: :object,
            properties: %{
              batch_data_container: BatchDataContainer,
              data_hash: %Schema{type: :string, nullable: true, description: "AnyTrust data hash."},
              timeout: %Schema{type: :string, nullable: true, description: "Data availability timeout (ISO 8601)."},
              bls_signature: %Schema{
                type: :string,
                nullable: true,
                description: "Aggregated BLS signature of committee members."
              },
              signers: %Schema{
                type: :array,
                description: "Committee members who guaranteed data availability.",
                items: %Schema{
                  type: :object,
                  properties: %{
                    trusted: %Schema{type: :boolean, description: "Whether the signer is a trusted member."},
                    key: %Schema{type: :string, description: "BLS public key."},
                    proof: %Schema{type: :string, description: "Proof of possession (absent for trusted members)."}
                  },
                  required: [:trusted, :key],
                  additionalProperties: false
                }
              }
            },
            required: [:batch_data_container, :data_hash, :timeout, :bls_signature, :signers],
            additionalProperties: false
          },
          # Variant: in_celestia
          %Schema{
            type: :object,
            properties: %{
              batch_data_container: BatchDataContainer,
              height: %Schema{type: :integer, nullable: true, description: "Celestia block height."},
              transaction_commitment: %Schema{
                type: :string,
                nullable: true,
                description: "Celestia transaction commitment hash."
              }
            },
            required: [:batch_data_container, :height, :transaction_commitment],
            additionalProperties: false
          },
          # Variant: in_eigenda
          %Schema{
            type: :object,
            properties: %{
              batch_data_container: BatchDataContainer,
              blob_header: %Schema{
                type: :string,
                nullable: true,
                description: "ABI-encoded EigenDA blob header."
              },
              blob_verification_proof: %Schema{
                type: :string,
                nullable: true,
                description: "ABI-encoded EigenDA blob verification proof."
              }
            },
            required: [:batch_data_container, :blob_header, :blob_verification_proof],
            additionalProperties: false
          }
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
