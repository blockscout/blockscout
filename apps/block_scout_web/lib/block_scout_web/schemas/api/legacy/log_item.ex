# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.Legacy.LogItem do
  @moduledoc false
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      address: General.AddressHash,
      # Each topic slot is nullable: RPC.LogsView.get_topics/1 always returns a
      # 4-element list, filling unset slots with nil. A non-nullable items schema
      # would fail validation on any real log with <4 topics.
      topics: %Schema{
        type: :array,
        minItems: 4,
        maxItems: 4,
        description: "32-byte indexed event topics. Always a 4-element array; unfilled slots are `null`.",
        items: General.FullHashNullable
      },
      data: %Schema{
        type: :string,
        pattern: General.hex_data_pattern(),
        description: "Hex-encoded event data payload (`0x`-prefixed, arbitrary length)."
      },
      blockNumber: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded block number."
      },
      timeStamp: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded Unix timestamp in seconds of the block."
      },
      gasPrice: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded gas price in wei."
      },
      gasUsed: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded gas used by the transaction."
      },
      logIndex: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded position of the log within the block."
      },
      transactionHash: General.FullHash,
      transactionIndex: %Schema{
        type: :string,
        pattern: General.hex_quantity_pattern(),
        description: "Hex-encoded position of the transaction within the block."
      }
    },
    required: [
      :address,
      :topics,
      :data,
      :blockNumber,
      :timeStamp,
      :gasPrice,
      :gasUsed,
      :logIndex,
      :transactionHash,
      :transactionIndex
    ],
    additionalProperties: false
  })
end
