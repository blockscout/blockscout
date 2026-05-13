# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Shibarium.Withdrawal do
  @moduledoc """
  This module defines the schema for the Shibarium Withdrawal struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ShibariumWithdrawal",
    description: "Shibarium withdrawal item that bridges assets from Shibarium to the parent chain.",
    type: :object,
    properties: %{
      l2_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "Shibarium block in which the withdrawal was initiated."
      },
      l2_transaction_hash: %Schema{
        allOf: [General.FullHashNullable],
        description: "Hash of the Shibarium transaction that initiates the withdrawal."
      },
      l1_transaction_hash: %Schema{
        allOf: [General.FullHashNullable],
        description: "Hash of the parent chain transaction that completes the withdrawal."
      },
      user: %Schema{
        allOf: [Address],
        description:
          "Address of the user that initiated the withdrawal on Shibarium; the same address acts as the recipient on the parent chain."
      },
      timestamp:
        Helper.extend_schema(General.TimestampNullable.schema(),
          description: "Timestamp of the Shibarium block that contains the withdrawal transaction."
        )
    },
    required: [
      :l2_block_number,
      :l2_transaction_hash,
      :l1_transaction_hash,
      :user,
      :timestamp
    ],
    additionalProperties: false
  })
end
