# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.Envelope do
  @moduledoc false

  alias OpenApiSpex.Schema

  @doc """
  Returns an OpenAPI schema for the RPC response envelope:
  `{"status": "0"|"1"|"2", "message": "...", "result": <result_schema>}`.
  """
  @spec rpc_envelope(module()) :: Schema.t()
  def rpc_envelope(result_schema) do
    %Schema{
      type: :object,
      properties: %{
        status: %Schema{
          type: :string,
          enum: ["0", "1", "2"],
          description: "`1` = OK, `0` = error, `2` = pending."
        },
        message: %Schema{
          type: :string,
          description:
            "Human-readable status string — `OK` on success, " <>
              "a descriptive error message otherwise."
        },
        result: result_schema
      },
      required: [:status, :message, :result],
      additionalProperties: false
    }
  end

  @doc """
  Returns an OpenAPI schema for the JSON-RPC 2.0 response envelope, covering
  both success and error shapes:

    - success: `{"jsonrpc": "2.0", "result": <result_schema>, "id": <integer|string>}`
    - error:   `{"jsonrpc": "2.0", "error":  <string|object>, "id": <integer|string>}`

  Modelled as `oneOf` because the two shapes are mutually exclusive — the
  `EthRPCView` encoder emits `result` or `error`, never both.
  """
  @spec eth_rpc_envelope(module()) :: Schema.t()
  def eth_rpc_envelope(result_schema) do
    %Schema{
      description: "JSON-RPC 2.0 response envelope — `result` on success, `error` on failure.",
      oneOf: [
        eth_rpc_success_envelope(result_schema),
        eth_rpc_error_envelope()
      ]
    }
  end

  @spec eth_rpc_success_envelope(module()) :: Schema.t()
  defp eth_rpc_success_envelope(result_schema) do
    %Schema{
      type: :object,
      properties: %{
        jsonrpc: jsonrpc_property(),
        result: result_schema,
        id: id_property()
      },
      required: [:jsonrpc, :result, :id],
      additionalProperties: false
    }
  end

  @spec eth_rpc_error_envelope() :: Schema.t()
  defp eth_rpc_error_envelope do
    %Schema{
      type: :object,
      properties: %{
        jsonrpc: jsonrpc_property(),
        error: %Schema{
          description: "Error description — a human-readable string or a JSON-RPC error object.",
          anyOf: [
            %Schema{type: :string},
            %Schema{
              type: :object,
              properties: %{
                code: %Schema{type: :integer, description: "JSON-RPC error code."},
                message: %Schema{type: :string, description: "Human-readable error description."}
              },
              required: [:code, :message],
              additionalProperties: false
            }
          ]
        },
        id: id_property()
      },
      required: [:jsonrpc, :error, :id],
      additionalProperties: false
    }
  end

  defp jsonrpc_property do
    %Schema{
      type: :string,
      enum: ["2.0"],
      description: "JSON-RPC protocol version, always `2.0`."
    }
  end

  defp id_property do
    %Schema{
      anyOf: [%Schema{type: :integer}, %Schema{type: :string}],
      description:
        "Echoes the request id as an integer or string. " <>
          "If the client sent `id: null`, the echo is coerced to an empty string. " <>
          "When the client omits `id` entirely, the response is always the error variant " <>
          "of this envelope with integer `0`."
    }
  end
end
