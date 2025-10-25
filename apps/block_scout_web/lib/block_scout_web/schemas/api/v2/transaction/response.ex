defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @op_interop_message_schema %Schema{
    type: :object,
    description: "Interop message included in an Optimism transaction",
    nullable: false,
    properties: %{
      nonce: %Schema{type: :integer, minimum: 0},
      payload: General.HexString,
      relay_chain: %Schema{
        type: :object,
        properties: %{
          instance_url: %Schema{type: :string, nullable: true},
          chain_id: General.IntegerString,
          chain_name: %Schema{type: :string, nullable: true},
          chain_logo: %Schema{type: :string, nullable: true}
        },
        nullable: true
      },
      relay_transaction_hash: General.FullHash,
      sender_address_hash: General.AddressHash,
      status: %Schema{type: :string, enum: ["Sent", "Relayed", "Failed"]},
      target_address_hash: General.AddressHash,
      unique_id: %Schema{type: :string}
    },
    required: [:payload],
    example: %{
      "nonce" => 0,
      "payload" => "0x30787849009c24f10a91a327a9f2ed94ebc49ee9",
      "relay_chain" => nil,
      "relay_transaction_hash" => "0x0000000000000000000000000000000000000000000000000000000000000002",
      "sender_address_hash" => "0x0000000000000000000000000000000000000003",
      "status" => "Relayed",
      "target_address_hash" => "0x0000000000000000000000000000000000000004",
      "unique_id" => "0000000100000000"
    }
  }

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties added based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  def chain_type_fields(schema) do
    case Application.get_env(:explorer, :chain_type) do
      :optimism ->
        schema
        |> Helper.extend_schema(
          properties: %{op_interop_messages: %Schema{type: :array, items: @op_interop_message_schema, nullable: false}}
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Response do
  @moduledoc """
  This module defines the schema for transaction response from /api/v2/transactions/:transaction_hash_param.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Transaction
  alias BlockScoutWeb.Schemas.API.V2.Transaction.Response.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.Helper

  OpenApiSpex.schema(
    Transaction.schema()
    |> Helper.extend_schema(
      title: "TransactionResponse",
      description: "Transaction response"
    )
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
