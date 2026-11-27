# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Token.DetailResponse do
  @moduledoc """
  This module defines the schema for the token detail response from
  /api/v2/tokens/:address_hash_param: the token fields plus its burned supply.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, Token}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @burn_address_balance %Schema{
    type: :object,
    nullable: false,
    properties: %{
      address_hash: General.AddressHash,
      value: Helper.describe_inline(General.IntegerString.schema(), "Raw balance held by `address_hash`.")
    },
    required: [:address_hash, :value],
    additionalProperties: false
  }

  OpenApiSpex.schema(
    Token.schema()
    |> Helper.extend_schema(
      title: "TokenDetailResponse",
      description: "Token response",
      properties: %{
        burn_address_balances: %Schema{
          type: :array,
          items: @burn_address_balance,
          nullable: true,
          description:
            "Indexed balances of the zero address (`0x0000000000000000000000000000000000000000`) and the dead address " <>
              "(`0x000000000000000000000000000000000000dEaD`). An address is left out while its balance after its " <>
              "latest transfer is not fetched yet. `null` when neither is listed or the token is not ERC-20 or ERC-8056."
        },
        burned_supply:
          Helper.describe_inline(
            General.IntegerStringNullable.schema(),
            "Sum of `burn_address_balances`: tokens sent to a burn address that are still counted in `total_supply`. " <>
              "`null` until both burn addresses are listed in `burn_address_balances`, for instance while they are " <>
              "being backfilled for a token indexed earlier, so a partial sum is never reported. " <>
              "Tokens destroyed by the contract itself already lowered `total_supply` and are not part of it. " <>
              "This assumes, as standard ERC-20 implementations do, that a burn lowering `total_supply` does not also " <>
              "credit a burn address balance. " <>
              "Raw, like `total_supply`: an ERC-8056 token takes the same `ui_multiplier` to display it."
          ),
        calculated_circulating_supply:
          Helper.describe_inline(
            General.IntegerStringNullable.schema(),
            "Circulating supply from indexed on-chain data, `total_supply - burned_supply`, in raw units, at the block " <>
              "at which `total_supply` was last read (the latest indexed block at the time of the read). A burn address " <>
              "balance is updated at every transfer that touches the address, and every mint or burn touches the zero " <>
              "address. The value is therefore `null` while either burn address had a transfer after that block, until " <>
              "`total_supply` is refreshed (requesting this endpoint schedules the refresh), and when the block of " <>
              "`total_supply` is unknown. It assumes the token balances of the blocks up to that block are imported; " <>
              "with asynchronous token balance import, a burn address transfer in the latest blocks can be missed " <>
              "until it is imported. Also `null` when `burned_supply` or `total_supply` is `null`, or when " <>
              "`burned_supply` exceeds `total_supply`. " <>
              "Unrelated to `circulating_supply`, which comes from the " <>
              "price source in that source's units and with its own method (it may also leave out treasury, locked " <>
              "or vesting balances); `circulating_market_cap` is based on the price source only."
          )
      },
      required: [:burn_address_balances, :burned_supply, :calculated_circulating_supply]
    )
  )
end
