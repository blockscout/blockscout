# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Token.Counters do
  @moduledoc """
  This module defines the schema for the response from /api/v2/tokens/:address_hash_param/counters.
  Example response: {"token_holders_count":"0","transfers_count":"0","ui_multiplier_changes_count":"0"}
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%Schema{
    title: "TokenCountersResponse",
    description: "Token counters response",
    type: :object,
    properties: %{
      token_holders_count: General.IntegerString,
      transfers_count: General.IntegerString,
      ui_multiplier_changes_count: %Schema{
        allOf: [General.IntegerString],
        description:
          "Number of ERC-8056 multiplier changes listed by `/api/v2/tokens/{address_hash}/ui-multiplier-changes`. Always `\"0\"` for a token that does not implement ERC-8056."
      }
    },
    required: [:token_holders_count, :transfers_count, :ui_multiplier_changes_count],
    additionalProperties: false,
    example: %{token_holders_count: "0", transfers_count: "0", ui_multiplier_changes_count: "0"}
  })
end
