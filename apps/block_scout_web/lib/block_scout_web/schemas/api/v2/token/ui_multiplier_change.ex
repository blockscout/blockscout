# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Token.UIMultiplierChange do
  @moduledoc """
  This module defines the schema for one entry of the ERC-8056 multiplier
  history of a token, as returned by
  /api/v2/tokens/:address_hash_param/ui-multiplier-changes.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%Schema{
    title: "TokenUIMultiplierChange",
    description:
      "A single `UIMultiplierUpdated` event of an ERC-8056 token: the multiplier it replaces, the one it schedules, and the moment that one takes effect.",
    type: :object,
    properties: %{
      block_number: %Schema{type: :integer, nullable: false},
      block_hash: General.FullHash,
      timestamp:
        Helper.extend_schema(General.Timestamp.schema(),
          description: "Moment the change was announced, i.e. the timestamp of the block holding the event."
        ),
      transaction_hash:
        Helper.extend_schema(General.FullHashNullable.schema(),
          description:
            "Transaction the event was emitted from. `null` for changes recorded before this field existed and for chains that emit logs outside of a transaction."
        ),
      log_index: %Schema{type: :integer, nullable: false},
      old_multiplier:
        Helper.extend_schema(General.IntegerString.schema(),
          description: "Multiplier in force until `effective_at`, with 18 decimals of precision."
        ),
      new_multiplier:
        Helper.extend_schema(General.IntegerString.schema(),
          description: "Multiplier in force from `effective_at` on, with 18 decimals of precision."
        ),
      effective_at:
        Helper.extend_schema(General.Timestamp.schema(),
          description:
            "Moment `new_multiplier` replaces `old_multiplier`. A moment still in the future means the change is announced but pending."
        )
    },
    required: [
      :block_number,
      :block_hash,
      :timestamp,
      :transaction_hash,
      :log_index,
      :old_multiplier,
      :new_multiplier,
      :effective_at
    ],
    additionalProperties: false,
    example: %{
      block_number: 12_345,
      block_hash: "0x3a2b4c07b7e4ec0a2e67d8e6e2f5c8f6a1f1f0c1c2f7d1d8e5b0a9c3d4e5f607",
      timestamp: "2026-09-01T00:00:00.000000Z",
      transaction_hash: "0x9f8e7d6c5b4a39281706f5e4d3c2b1a09f8e7d6c5b4a39281706f5e4d3c2b1a0",
      log_index: 3,
      old_multiplier: "1000000000000000000",
      new_multiplier: "2000000000000000000",
      effective_at: "2026-09-05T00:00:00.000000Z"
    }
  })
end
