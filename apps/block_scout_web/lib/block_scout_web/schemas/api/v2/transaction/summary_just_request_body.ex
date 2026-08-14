# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.SummaryJustRequestBody do
  @moduledoc """
  OpenAPI schema for the transaction summary just request body response.
  """
  require OpenApiSpex

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.Schemas.API.V2.{Address, InternalTransaction, Log, TokenTransfer}
  alias BlockScoutWeb.Schemas.API.V2.Eden.Call, as: EdenCall
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  logs_data_schema = %Schema{
    type: :object,
    required: [:items],
    properties: %{
      items: %Schema{type: :array, items: %Schema{allOf: [Log], nullable: true}}
    },
    additionalProperties: false
  }

  data_schema = %Schema{
    type: :object,
    required: [
      :status,
      :type,
      :value,
      :hash,
      :from,
      :to,
      :method,
      :token_transfers,
      :internal_transactions,
      :transaction_types,
      :decoded_input,
      :raw_input
    ],
    properties: %{
      status: %Schema{type: :string},
      type: %Schema{type: :integer, nullable: true},
      value: %Schema{type: :string},
      hash: %Schema{type: :string},
      from: %Schema{allOf: [Address], nullable: true},
      to: %Schema{allOf: [Address], nullable: true},
      method: %Schema{type: :string, nullable: true},
      token_transfers: %Schema{type: :array, items: %Schema{allOf: [TokenTransfer], nullable: true}},
      internal_transactions: %Schema{type: :array, items: %Schema{allOf: [InternalTransaction], nullable: true}},
      transaction_types: %Schema{type: :array, items: %Schema{type: :string}},
      decoded_input: %Schema{type: :object, nullable: true},
      raw_input: %Schema{type: :string}
    },
    additionalProperties: false
  }

  data_schema =
    case @chain_type do
      :eden ->
        Helper.extend_schema(data_schema,
          properties: %{
            fee_payer: %Schema{allOf: [Address], nullable: true},
            calls: %Schema{type: :array, items: EdenCall, nullable: true}
          }
        )

      _ ->
        data_schema
    end

  OpenApiSpex.schema(%{
    type: :object,
    required: [:data],
    properties: %{
      chain_id: %Schema{type: :integer, nullable: true},
      data: data_schema,
      logs_data: logs_data_schema
    },
    additionalProperties: false
  })
end
