defmodule BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias OpenApiSpex.Schema

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  case @chain_type do
    :filecoin ->
      @filecoin_robust_address_schema %Schema{
        type: :string,
        example: "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq",
        nullable: true
      }

      def chain_type_fields(schema) do
        schema
        |> put_in([:properties, :creator_filecoin_robust_address], @filecoin_robust_address_schema)
        |> update_in([:required], &[:creator_filecoin_robust_address | &1])
      end

    :zilliqa ->
      def chain_type_fields(schema) do
        schema
        |> put_in([:properties, :is_scilla_contract], %Schema{type: :boolean, nullable: false})
      end

    _ ->
      def chain_type_fields(schema), do: schema
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Address.Response do
  @moduledoc """
  This module defines the schema for address response from /api/v2/addresses/:hash.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Address.Response.ChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.{General, Token}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AddressResponse",
    description: "Address response",
    type: :object,
    allOf: [
      BlockScoutWeb.Schemas.API.V2.Address,
      struct(
        Schema,
        %{
          type: :object,
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
            has_beacon_chain_withdrawals: %Schema{type: :boolean, nullable: false}
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
            :has_beacon_chain_withdrawals
          ]
        }
        |> ChainTypeCustomizations.chain_type_fields()
      )
    ]
  })
end
