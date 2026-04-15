defmodule BlockScoutWeb.Schemas.API.V2.Legacy.Envelope do
  @moduledoc false

  alias OpenApiSpex.Schema

  @doc """
  Returns an OpenAPI schema for the Etherscan-style RPC envelope:
  `{"status": "0"|"1"|"2", "message": "...", "result": <result_schema>}`.
  """
  @spec rpc_envelope(Schema.t()) :: Schema.t()
  def rpc_envelope(result_schema) do
    %Schema{
      type: :object,
      properties: %{
        status: %Schema{
          type: :string,
          enum: ["0", "1", "2"],
          description:
            "Etherscan status sentinel: `1` = OK, `0` = error, `2` = pending " <>
              "(used by other legacy endpoints)."
        },
        message: %Schema{
          type: :string,
          description:
            "Human-readable status string — `OK` on success, " <>
              "a descriptive error message otherwise."
        },
        result: %Schema{
          description: "Endpoint-specific payload on success; `null` on error.",
          allOf: [result_schema]
        }
      },
      required: [:status, :message, :result],
      additionalProperties: false
    }
  end

  @doc """
  Returns an OpenAPI schema for the JSON-RPC 2.0 envelope:
  `{"jsonrpc": "2.0", "result": <result_schema>, "id": <integer|string>}`.
  """
  @spec eth_rpc_envelope(Schema.t()) :: Schema.t()
  def eth_rpc_envelope(result_schema) do
    %Schema{
      type: :object,
      properties: %{
        jsonrpc: %Schema{
          type: :string,
          enum: ["2.0"],
          description: "JSON-RPC protocol version, always `2.0`."
        },
        result: %Schema{
          description: "Endpoint-specific payload.",
          allOf: [result_schema]
        },
        id: %Schema{
          anyOf: [%Schema{type: :integer}, %Schema{type: :string}],
          description:
            "Echoes the request id. When the client omits it, " <>
              "the server echoes integer `1`."
        }
      },
      required: [:jsonrpc, :result, :id],
      additionalProperties: false
    }
  end
end
