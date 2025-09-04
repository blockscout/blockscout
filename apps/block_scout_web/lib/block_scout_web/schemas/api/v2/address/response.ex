defmodule BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @filecoin_robust_address_schema %Schema{
    type: :string,
    description: "Robust f0/f1/f2/f3/f4 Filecoin address",
    example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
    nullable: true
  }

  @zilliqa_schema %Schema{
    type: :object,
    properties: %{
      is_scilla_contract: %Schema{type: :boolean, nullable: false}
    },
    required: [:is_scilla_contract],
    additionalProperties: false
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
      :filecoin ->
        schema
        |> Helper.extend_schema(
          properties: %{creator_filecoin_robust_address: @filecoin_robust_address_schema},
          required: [:creator_filecoin_robust_address]
        )

      :zilliqa ->
        schema
        |> Helper.extend_schema(
          properties: %{zilliqa: @zilliqa_schema},
          required: [:zilliqa]
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Address.Response do
  @moduledoc """
  This module defines the schema for address response from /api/v2/addresses/:hash.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Address.schema()
    |> Helper.extend_schema(
      title: "AddressResponse",
      description: "Address response",
      properties: %{
        creator_address_hash: General.AddressHashNullable,
        creation_transaction_hash: General.FullHashNullable,
        token: %Schema{allOf: [Token], nullable: true},
        coin_balance: General.IntegerStringNullable,
        exchange_rate: General.FloatStringNullable,
        block_number_balance_updated_at: %Schema{type: :integer, minimum: 0, nullable: true},
        has_validated_blocks: %Schema{type: :boolean, nullable: false},
        has_logs: %Schema{type: :boolean, nullable: false},
        has_tokens: %Schema{type: :boolean, nullable: false},
        has_token_transfers: %Schema{type: :boolean, nullable: false},
        watchlist_address_id: %Schema{type: :integer, nullable: true},
        has_beacon_chain_withdrawals: %Schema{type: :boolean, nullable: false},
        creation_status: %Schema{
          type: :string,
          description: "Creation status of the contract",
          enum: ["success", "failed", "selfdestructed"],
          nullable: true
        }
      },
      required: [
        :creator_address_hash,
        :creation_transaction_hash,
        :token,
        :coin_balance,
        :exchange_rate,
        :block_number_balance_updated_at,
        :has_validated_blocks,
        :has_logs,
        :has_tokens,
        :has_token_transfers,
        :watchlist_address_id,
        :has_beacon_chain_withdrawals,
        :creation_status
      ]
    )
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
