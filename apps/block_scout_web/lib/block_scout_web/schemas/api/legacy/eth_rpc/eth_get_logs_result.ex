# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.EthRpc.EthGetLogsResult do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  # Shape returned by Explorer.EthRPC.render_log/1 — differs from the RPC-envelope
  # LogItem (which includes timeStamp, gasPrice, gasUsed instead of blockHash/removed).
  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      address: General.AddressHash,
      blockHash: General.FullHash,
      blockNumber: %Schema{
        type: :string,
        pattern: ~r/^0x[0-9a-fA-F]+$/,
        description: "Hex-encoded block number."
      },
      data: %Schema{
        type: :string,
        pattern: ~r/^0x[0-9a-fA-F]*$/,
        description: "Hex-encoded event data payload."
      },
      logIndex: %Schema{
        type: :string,
        pattern: ~r/^0x[0-9a-fA-F]+$/,
        description: "Hex-encoded position of the log within the block."
      },
      removed: %Schema{
        type: :boolean,
        description: "`true` if the log was removed due to a chain reorganization."
      },
      topics: %Schema{
        type: :array,
        description: "Indexed event topics. Up to four 32-byte hex strings; unused slots are `null`.",
        items: %Schema{
          type: :string,
          pattern: ~r/^0x[0-9a-fA-F]{64}$/,
          nullable: true
        }
      },
      transactionHash: General.FullHash,
      transactionIndex: %Schema{
        type: :string,
        pattern: ~r/^0x[0-9a-fA-F]+$/,
        description: "Hex-encoded position of the transaction within the block."
      }
    },
    required: [
      :address,
      :blockHash,
      :blockNumber,
      :data,
      :logIndex,
      :removed,
      :topics,
      :transactionHash,
      :transactionIndex
    ]
  })
end
