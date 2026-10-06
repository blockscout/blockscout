# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Celo.Epoch.Distribution do
  @moduledoc """
  Epoch reward distribution as rendered for a Celo epoch list item
  (`CeloViewView.prepare_epoch/1`). Each transfer carries the token-transfer
  total amount (or token id), and `transfers_total` is the aggregated sum.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.TokenTransfer
  alias OpenApiSpex.Schema

  # Same shape as `TokenTransfer.total` (produced by `prepare_token_transfer_total/1`):
  # fungible `{value, decimals}`, ERC-721 `{token_id, token_instance}`, or
  # ERC-1155/404 `{token_id, value, decimals, token_instance}`.
  @transfer_total %Schema{
    anyOf: [TokenTransfer.TotalERC721, TokenTransfer.TotalERC1155, TokenTransfer.Total],
    nullable: true,
    description: "Total amount (or token id) of the epoch reward transfer; `null` when the transfer is absent."
  }

  OpenApiSpex.schema(%{
    title: "CeloEpochDistribution",
    description: "Epoch reward transfers and their aggregated total.",
    type: :object,
    properties: %{
      reserve_bolster_transfer: @transfer_total,
      community_transfer: @transfer_total,
      carbon_offsetting_transfer: @transfer_total,
      transfers_total: %Schema{
        allOf: [TokenTransfer.Total],
        nullable: true,
        description: "Aggregated total of all reward transfers; `null` when there are no transfers."
      }
    },
    required: [
      :reserve_bolster_transfer,
      :community_transfer,
      :carbon_offsetting_transfer,
      :transfers_total
    ],
    additionalProperties: false
  })
end
