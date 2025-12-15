defmodule BlockScoutWeb.Schemas.API.V2.Transaction.RawTrace do
  @moduledoc """
  This module defines the schema for a transaction raw trace API response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  action_schema = %Schema{
    type: :object,
    properties: %{
      callType: %Schema{type: :string, enum: ["call", "callcode", "delegatecall", "staticcall"]},
      from: General.AddressHash,
      gas: General.HexString,
      input: General.HexString,
      init: General.HexString,
      to: General.AddressHash,
      value: General.HexString
    },
    required: [:from, :gas, :input, :value],
    additionalProperties: false
  }

  result_schema = %Schema{
    type: :object,
    properties: %{
      gasUsed: General.HexString,
      output: General.HexString
    },
    required: [:gasUsed, :output],
    additionalProperties: false
  }

  trace_schema = %Schema{
    type: :object,
    properties: %{
      action: action_schema,
      result: result_schema,
      subtraces: %Schema{type: :integer, minimum: 0},
      traceAddress: %Schema{type: :array, items: %Schema{type: :integer}},
      transactionHash: General.FullHashNullable,
      type: %Schema{type: :string, enum: ["call", "create", "create2", "reward", "selfdestruct", "stop", "invalid"]}
    },
    required: [:action, :subtraces, :traceAddress, :type],
    additionalProperties: false
  }

  OpenApiSpex.schema(%Schema{
    type: :array,
    items: trace_schema
  })
end
