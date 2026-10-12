# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer.PoisoningAttack do
  @moduledoc """
  The address poisoning verdict of a token transfer, present only on the
  transfers the indexer identified as attacks.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  @rules [
    "zero_amount",
    "sender_mismatch",
    "suspicious_outgoing",
    "initiator_fanout",
    "dust_from_counterparty",
    "scam_flag",
    "lookalike_recipient",
    "name_imitation"
  ]

  OpenApiSpex.schema(%{
    title: "TokenTransferPoisoningAttack",
    description: "Why the transfer was identified as an address poisoning attack and who took part in it",
    type: :object,
    properties: %{
      score: %Schema{
        type: :integer,
        description: "Sum of the weights of the rules that fired; at or above the instance's threshold",
        nullable: false
      },
      rules: %Schema{
        type: :array,
        items: %Schema{type: :string, enum: @rules},
        description: "Names of the rules that fired, heaviest first",
        nullable: false
      },
      details: %Schema{
        type: :object,
        description: "What each rule matched, keyed by rule name",
        additionalProperties: true,
        nullable: false
      },
      victim: General.AddressHash,
      mimic: General.AddressHash,
      issuer: General.AddressHashNullable
    },
    required: [:score, :rules, :details, :victim, :mimic, :issuer],
    additionalProperties: false,
    nullable: true
  })
end
