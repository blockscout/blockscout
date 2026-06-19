# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Optimism.InteropMessage do
  @moduledoc """
  Schema for an interop message included in an Optimism transaction (an item of
  `Transaction.op_interop_messages`).

  Depending on the message direction, each item carries either the
  `init_chain` / `init_transaction_hash` pair (incoming) or the
  `relay_chain` / `relay_transaction_hash` pair (outgoing) — hence all four are
  optional. Matches `Explorer.Chain.Optimism.InteropMessage.messages_by_transaction/1`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  # `interop_chain_id_to_instance_info/2` result; same shape for `init_chain` and `relay_chain`.
  @chain_info %Schema{
    type: :object,
    nullable: true,
    properties: %{
      instance_url: %Schema{type: :string, nullable: true},
      chain_id: General.IntegerString,
      chain_name: %Schema{type: :string, nullable: true},
      chain_logo: %Schema{type: :string, nullable: true}
    }
  }

  OpenApiSpex.schema(%{
    title: "OptimismInteropMessage",
    description: "Interop message included in an Optimism transaction",
    type: :object,
    nullable: false,
    properties: %{
      unique_id: %Schema{type: :string},
      nonce: %Schema{type: :integer, minimum: 0},
      status: %Schema{type: :string, enum: ["Sent", "Relayed", "Failed"]},
      sender_address_hash: General.AddressHash,
      target_address_hash: General.AddressHash,
      payload: General.HexString,
      init_chain: @chain_info,
      init_transaction_hash: General.FullHash,
      relay_chain: @chain_info,
      relay_transaction_hash: General.FullHash
    },
    required: [:payload],
    example: %{
      "unique_id" => "0000000100000000",
      "nonce" => 0,
      "status" => "Relayed",
      "sender_address_hash" => "0x0000000000000000000000000000000000000003",
      "target_address_hash" => "0x0000000000000000000000000000000000000004",
      "payload" => "0x30787849009c24f10a91a327a9f2ed94ebc49ee9",
      "relay_chain" => nil,
      "relay_transaction_hash" => "0x0000000000000000000000000000000000000000000000000000000000000002"
    }
  })
end
