# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.StateChange do
  @moduledoc """
  This module defines the schema for a transaction state change API response.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    required: [
      :address,
      :balance_after,
      :balance_before,
      :change,
      :is_miner,
      :token,
      :type,
      :ui_multiplier
    ],
    properties: %{
      # Should reference Address schema if available
      address: Address,
      balance_after: General.IntegerStringNullable,
      balance_before: General.IntegerStringNullable,
      change: General.IntegerStringNullable,
      is_miner: %Schema{type: :boolean},
      token: %Schema{allOf: [Token], nullable: true},
      token_id: General.IntegerStringNullable,
      type: %Schema{type: :string, enum: ["token", "coin"]},
      ui_multiplier: %Schema{
        allOf: [General.IntegerStringNullable],
        description:
          "ERC-8056 multiplier `balance_before`, `balance_after` and `change` are to be displayed with, as of this transaction, with 18 decimals of precision. The nested `token.ui_multiplier` is the one in force now, not then."
      }
    },
    additionalProperties: false
  })
end
