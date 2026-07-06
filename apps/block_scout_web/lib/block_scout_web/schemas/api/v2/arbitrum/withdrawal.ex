# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Arbitrum.Withdrawal do
  @moduledoc "Schema for an Arbitrum Rollup withdrawal message (L2ToL1Tx event)."

  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ArbitrumWithdrawal",
    description: "Arbitrum Rollup withdrawal message.",
    type: :object,
    required: [
      :id,
      :status,
      :caller_address_hash,
      :destination_address_hash,
      :arb_block_number,
      :eth_block_number,
      :l2_timestamp,
      :callvalue,
      :data,
      :token,
      :completion_transaction_hash
    ],
    properties: %{
      id: %Schema{type: :integer, minimum: 0, description: "Withdrawal message ID."},
      # Status values must be kept in sync with Explorer.Arbitrum.Withdraw :status type.
      status: %Schema{
        type: :string,
        enum: ["unknown", "initiated", "sent", "confirmed", "relayed"],
        description:
          "Withdrawal lifecycle status. " <>
            "Progresses from `initiated` (L2ToL1Tx event emitted) through `sent` (included in an RBlock) " <>
            "and `confirmed` (RBlock confirmed on Parent chain) to `relayed` (executed on Parent chain). " <>
            "`unknown` indicates the status could not be determined, e.g. when the Parent chain RPC is unavailable."
      },
      caller_address_hash:
        Helper.describe_inline(
          General.AddressHash.schema(),
          "Address of the account that initiated the withdrawal on the Rollup."
        ),
      destination_address_hash:
        Helper.describe_inline(
          General.AddressHash.schema(),
          "Recipient address on the Parent chain that will receive funds when the withdrawal is executed."
        ),
      arb_block_number: %Schema{type: :integer, minimum: 0, description: "Rollup block number."},
      eth_block_number: %Schema{type: :integer, minimum: 0, description: "Parent chain block number."},
      l2_timestamp: %Schema{type: :integer, minimum: 0, description: "Unix timestamp of the originating transaction."},
      callvalue:
        Helper.describe_inline(
          General.IntegerString.schema(),
          "Native coin amount in wei attached to the withdrawal message."
        ),
      data:
        Helper.describe_inline(
          General.HexData.schema(),
          "ABI-encoded calldata passed to the destination address when the withdrawal is executed on the Parent chain. " <>
            "Empty (`0x`) for plain native coin transfers."
        ),
      token: %Schema{
        type: :object,
        nullable: true,
        description:
          "Token withdrawal details. Present when the withdrawal is for a bridged token, null for native coin.",
        properties: %{
          address_hash:
            Helper.describe_inline(
              General.AddressHashNullable.schema(),
              "Token contract address on the Parent chain."
            ),
          destination_address_hash:
            Helper.describe_inline(
              General.AddressHashNullable.schema(),
              "Token recipient address on the Parent chain."
            ),
          amount:
            Helper.describe_inline(
              General.IntegerString.schema(),
              "Token amount in the token's smallest unit."
            ),
          decimals: %Schema{type: :integer, minimum: 0, nullable: true},
          name: %Schema{type: :string, nullable: true},
          symbol: %Schema{type: :string, nullable: true}
        },
        required: [:address_hash, :destination_address_hash, :amount, :decimals, :name, :symbol],
        additionalProperties: false
      },
      completion_transaction_hash: General.FullHashNullable
    },
    additionalProperties: false
  })
end
