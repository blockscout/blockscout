defmodule BlockScoutWeb.Schemas.API.V2.Zilliqa.Staker.Detailed do
  @moduledoc """
  This module defines the schema for Zilliqa validator info response from /api/v2/validators/zilliqa/:bls_public_key
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{AddressNullable, General}
  alias BlockScoutWeb.Schemas.API.V2.Zilliqa.Staker
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Staker.schema()
    |> Helper.extend_schema(
      title: "StakerDetailed",
      properties: %{
        peer_id: General.HexStringNullable,
        control_address: AddressNullable,
        reward_address: AddressNullable,
        signing_address: AddressNullable,
        added_at_block_number: %Schema{type: :integer, nullable: false},
        stake_updated_at_block_number: %Schema{type: :integer, nullable: false}
      },
      required: [
        :peer_id,
        :control_address,
        :reward_address,
        :signing_address,
        :added_at_block_number,
        :stake_updated_at_block_number
      ]
    )
  )
end
