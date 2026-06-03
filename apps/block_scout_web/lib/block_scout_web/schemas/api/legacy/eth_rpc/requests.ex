# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.Requests do
  @moduledoc """
  Request-body schemas for `/api/legacy/eth/*` endpoints.

  Each helper returns an `OpenApiSpex.RequestBody` shaped as a single JSON-RPC 2.0
  object (never an array) with `method` pinned to one literal value via `enum`.
  Batch requests are out of scope for these endpoints.
  """

  alias BlockScoutWeb.Schemas.API.Legacy.EthRpc.BlockTag
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.{MediaType, RequestBody, Schema}

  @id_schema %Schema{
    description: "JSON-RPC request id. Echoed back in the response.",
    anyOf: [%Schema{type: :integer}, %Schema{type: :string}],
    nullable: true
  }

  @jsonrpc_schema %Schema{
    type: :string,
    enum: ["2.0"],
    description: "JSON-RPC protocol version, always `2.0`."
  }

  # `additionalProperties: false` is intentionally NOT set on this schema.
  # The Blockscout-side `eth_call_validator/1` only inspects the six fields
  # listed below; any additional EVM call-object fields (e.g. `nonce`, `data`,
  # `chainId`, `type`, `accessList`, `maxFeePerGas`, `maxPriorityFeePerGas`,
  # `blobVersionedHashes`) pass validation untouched and are relayed verbatim
  # to the upstream JSON-RPC node by `Explorer.EthRPC.json_rpc/1`, where they
  # do influence execution. They are deliberately omitted from `properties:`
  # because Blockscout itself does not process them — listing them would
  # falsely imply Blockscout-side schema enforcement that does not exist.
  # Closing the object with `additionalProperties: false` would break this
  # passthrough by rejecting valid Ethereum call objects at the schema layer.
  @eth_call_object_schema %Schema{
    type: :object,
    description:
      "Transaction call object — at minimum `to` is required. " <>
        "Additional EVM call-object fields (`nonce`, `data`, `chainId`, `type`, " <>
        "`accessList`, `maxFeePerGas`, `maxPriorityFeePerGas`, `blobVersionedHashes`) " <>
        "are forwarded verbatim to the upstream JSON-RPC node and are not enforced here.",
    properties: %{
      to: Helper.describe_inline(General.AddressHash.schema(), "Target contract address."),
      from:
        Helper.describe_inline(
          General.AddressHash.schema(),
          "Caller address used as `msg.sender` during execution. Optional."
        ),
      gas: Helper.describe_inline(General.HexQuantity.schema(), "Hex-encoded gas limit."),
      gasPrice: Helper.describe_inline(General.HexQuantity.schema(), "Hex-encoded gas price in wei."),
      value: Helper.describe_inline(General.HexQuantity.schema(), "Hex-encoded value sent with the call, in wei."),
      input: Helper.describe_inline(General.HexData.schema(), "Hex-encoded calldata.")
    },
    required: [:to]
  }

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-call`.
  """
  @spec eth_call() :: RequestBody.t()
  def eth_call do
    json_rpc_body(
      method: "eth_call",
      params_schema: %Schema{
        type: :array,
        minItems: 2,
        maxItems: 2,
        items: %Schema{anyOf: [@eth_call_object_schema, BlockTag]},
        description:
          "Two-element array `[<call object>, <block tag>]`: " <>
            "the call object specifies the target contract and call data; " <>
            "the block tag selects the chain state to execute against."
      },
      example: %{
        "jsonrpc" => "2.0",
        "id" => 0,
        "method" => "eth_call",
        "params" => [
          %{
            "to" => "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F",
            "input" => "0xd4aae0c4",
            "from" => "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"
          },
          "latest"
        ]
      }
    )
  end

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-get-balance`.
  """
  @spec eth_get_balance() :: RequestBody.t()
  def eth_get_balance do
    json_rpc_body(
      method: "eth_getBalance",
      params_schema: %Schema{
        type: :array,
        minItems: 1,
        maxItems: 2,
        items: %Schema{anyOf: [General.AddressHash, BlockTag]},
        description:
          "One- or two-element array `[<address>]` or `[<address>, <block tag>]`: " <>
            "the address is the account to query; " <>
            "the block tag selects the chain state to read from and defaults to `\"latest\"` when omitted."
      },
      example: %{
        "jsonrpc" => "2.0",
        "id" => 0,
        "method" => "eth_getBalance",
        "params" => ["0x0000000000000000000000000000000000000007", "latest"]
      }
    )
  end

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-get-storage-at`.
  """
  @spec eth_get_storage_at() :: RequestBody.t()
  def eth_get_storage_at do
    json_rpc_body(
      method: "eth_getStorageAt",
      params_schema: %Schema{
        type: :array,
        minItems: 3,
        maxItems: 3,
        items: %Schema{
          anyOf: [
            General.AddressHash,
            General.HexQuantity,
            BlockTag
          ]
        },
        description:
          "Three-element array `[<address>, <storage position (hex)>, <block tag>]`: " <>
            "the address is the contract to query; " <>
            "the storage position is a hex-encoded slot index; " <>
            "the block tag selects the chain state to read from."
      },
      example: %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "eth_getStorageAt",
        "params" => ["0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F", "0x0", "latest"]
      }
    )
  end

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-send-raw-transaction`.
  """
  @spec eth_send_raw_transaction() :: RequestBody.t()
  def eth_send_raw_transaction do
    json_rpc_body(
      method: "eth_sendRawTransaction",
      params_schema: %Schema{
        type: :array,
        minItems: 1,
        maxItems: 1,
        description:
          "Single-element array `[<signed transaction data>]`: " <>
            "the signed transaction data is the RLP-encoded transaction bytes, hex-encoded with a `0x` prefix.",
        items: %Schema{
          type: :string,
          pattern: General.hex_quantity_pattern(),
          description: "Hex-encoded signed transaction bytes."
        }
      },
      example: %{
        "jsonrpc" => "2.0",
        "id" => 0,
        "method" => "eth_sendRawTransaction",
        "params" => ["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"]
      }
    )
  end

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-block-number`.
  """
  @spec eth_block_number() :: RequestBody.t()
  def eth_block_number do
    method = "eth_blockNumber"

    %RequestBody{
      required: true,
      description: "JSON-RPC 2.0 request body. `method` must be `#{method}`. No `params` field is needed.",
      content: %{
        "application/json" => %MediaType{
          schema: %Schema{
            type: :object,
            properties: %{
              jsonrpc: @jsonrpc_schema,
              id: @id_schema,
              method: %Schema{
                type: :string,
                enum: [method],
                description: "JSON-RPC method name. Must be `#{method}` for this endpoint."
              }
            },
            required: [:jsonrpc, :method, :id],
            example: %{
              "jsonrpc" => "2.0",
              "id" => 1,
              "method" => method
            }
          }
        }
      }
    }
  end

  @doc """
  Request body schema for `POST /api/legacy/eth/eth-get-logs`.
  """
  @spec eth_get_logs() :: RequestBody.t()
  def eth_get_logs do
    json_rpc_body(
      method: "eth_getLogs",
      params_schema: %Schema{
        type: :array,
        minItems: 1,
        maxItems: 1,
        description: "Single-element array containing a filter object.",
        items: %Schema{
          type: :object,
          description:
            "Log filter object. At least one of `address`, `topics` must be provided " <>
              "alongside `fromBlock` and `toBlock`.",
          properties: %{
            fromBlock: Helper.describe_inline(BlockTag.schema(), "Start of the block range to search."),
            toBlock: Helper.describe_inline(BlockTag.schema(), "End of the block range to search."),
            address:
              Helper.describe_inline(
                General.AddressHash.schema(),
                "Contract address to filter logs by. Optional."
              ),
            topics: %Schema{
              type: :array,
              description:
                "Up to four topic filters. Each element is either a 32-byte hex topic string, " <>
                  "an array of topic strings (OR semantics), or `null` to match any value in that position.",
              items: %Schema{
                nullable: true,
                anyOf: [
                  General.FullHash,
                  %Schema{type: :array, items: General.FullHash}
                ]
              }
            }
          }
        }
      },
      example: %{
        "jsonrpc" => "2.0",
        "id" => 0,
        "method" => "eth_getLogs",
        "params" => [
          %{
            "fromBlock" => "0x5",
            "toBlock" => "0xa",
            "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
          }
        ]
      }
    )
  end

  defp json_rpc_body(opts) do
    method = Keyword.fetch!(opts, :method)
    params_schema = Keyword.fetch!(opts, :params_schema)
    example = Keyword.fetch!(opts, :example)

    %RequestBody{
      required: true,
      description: "JSON-RPC 2.0 request body. `method` must be `#{method}`.",
      content: %{
        "application/json" => %MediaType{
          # `additionalProperties: false` is intentionally NOT set on this
          # outer JSON-RPC envelope. The dispatch chain
          # (`BlockScoutWeb.API.Legacy.EthController.dispatch/3` →
          # `BlockScoutWeb.API.EthRPC.EthController.eth_request/2` →
          # `Explorer.EthRPC.responses/1`) does not reject unknown top-level
          # keys; closing the envelope here would misrepresent the runtime.
          schema: %Schema{
            type: :object,
            properties: %{
              jsonrpc: @jsonrpc_schema,
              id: @id_schema,
              method: %Schema{
                type: :string,
                enum: [method],
                description: "JSON-RPC method name. Must be `#{method}` for this endpoint."
              },
              params: params_schema
            },
            required: [:jsonrpc, :method, :params, :id],
            example: example
          }
        }
      }
    }
  end
end
