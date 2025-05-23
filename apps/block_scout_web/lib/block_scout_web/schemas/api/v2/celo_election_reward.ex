defmodule BlockScoutWeb.Schemas.API.V2.CeloElectionReward do
  @moduledoc """
  This module defines the schema for the CeloElectionReward struct.
  """
  require OpenApiSpex
  alias Explorer.Chain.Celo.ElectionReward
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      block_number: %Schema{type: :integer, nullable: false},
      block_timestamp: General.Timestamp,
      block_hash: General.FullHash,
      account: Address,
      associated_account: Address,
      amount: General.IntegerString,
      type: %Schema{type: :string, nullable: false, enum: ElectionReward.types()},
      epoch_number: %Schema{type: :integer, nullable: false},
      token: Token
    },
    required: [
      :amount,
      :account,
      :associated_account
    ]
  })
end
