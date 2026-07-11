# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Address.TopAddress do
  @moduledoc """
  Schema for an item in the top-accounts list (`GET /api/v2/addresses`):
  the base `Address` plus its native-coin balance and transactions count.

  Built by extending `Address.schema()` (rather than referencing `Address` via
  `allOf`) because `Address` is a closed object (`additionalProperties: false`);
  a composition branch would reject the extra fields during response validation.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Address.schema()
    |> Helper.extend_schema(
      title: "TopAddress",
      description: "Address holding native coin, with its balance and transactions count",
      properties: %{
        coin_balance: General.IntegerStringNullable,
        transactions_count: %Schema{
          anyOf: [
            General.IntegerString,
            # TODO: replace empty string with null?
            General.EmptyString
          ],
          nullable: true
        }
      },
      required: [:coin_balance, :transactions_count]
    )
  )
end
