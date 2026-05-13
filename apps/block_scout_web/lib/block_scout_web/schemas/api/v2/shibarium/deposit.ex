# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Shibarium.Deposit do
  @moduledoc """
  This module defines the schema for the Shibarium Deposit struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ShibariumDeposit",
    description: "Shibarium deposit item that bridges assets from the parent chain to Shibarium.",
    type: :object,
    properties: %{
      l1_block_number: %Schema{
        type: :integer,
        minimum: 0,
        description: "Parent chain block in which the deposit was initiated."
      },
      l1_transaction_hash: %Schema{
        allOf: [General.FullHashNullable],
        description: "Hash of the parent chain transaction that initiates the deposit."
      },
      l2_transaction_hash: %Schema{
        allOf: [General.FullHashNullable],
        description: "Hash of the Shibarium transaction that completes the deposit."
      },
      user: %Schema{
        allOf: [Address],
        description:
          "Address of the user that initiated the deposit on the parent chain; the same address acts as the recipient on Shibarium."
      },
      timestamp:
        Helper.extend_schema(General.TimestampNullable.schema(),
          description: "Timestamp of the parent chain block that contains the deposit transaction."
        )
    },
    required: [
      :l1_block_number,
      :l1_transaction_hash,
      :l2_transaction_hash,
      :user,
      :timestamp
    ],
    additionalProperties: false
  })
end
