defmodule BlockScoutWeb.Schemas.API.V2.Stats.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties added based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  def chain_type_fields(schema) do
    case chain_type() do
      :rsk ->
        schema
        |> Helper.extend_schema(
          properties: %{
            rootstock_locked_btc: %Schema{type: :string, nullable: true, description: "Present on RSK chains only"}
          }
        )

      :optimism ->
        schema
        |> Helper.extend_schema(
          properties: %{
            last_output_root_size: %Schema{
              type: :string,
              nullable: true,
              description: "Present on Optimism chains only"
            }
          }
        )

      _ ->
        schema
    end
  end

  @doc """
   Applies chain identity-specific field customizations to the given schema based on the configured chain identity.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain identity-specific properties added based on the current chain identity configuration
  """
  @spec chain_identity_fields(map()) :: map()
  def chain_identity_fields(schema) do
    case chain_identity() do
      {:optimism, :celo} ->
        schema
        |> Helper.extend_schema(
          properties: %{
            celo: %Schema{
              type: :object,
              nullable: true,
              properties: %{epoch_number: %Schema{type: :integer, nullable: true}}
            }
          }
        )

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Stats.Response do
  @moduledoc """
  This module defines the schema for response from /api/v2/stats.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.API.V2.Stats.Response.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %Schema{
      type: :object,
      title: "StatsResponse",
      description: "Stats response",
      properties: %{
        total_blocks: General.IntegerString,
        total_addresses: General.IntegerString,
        total_transactions: General.IntegerString,
        average_block_time: %Schema{type: :number, format: :float},
        coin_image: %Schema{type: :string, nullable: true},
        secondary_coin_image: %Schema{type: :string, nullable: true},
        coin_price: %Schema{type: :number, nullable: true},
        coin_price_change_percentage: %Schema{type: :number, nullable: true},
        total_gas_used: General.IntegerString,
        secondary_coin_price: %Schema{type: :number, nullable: true},
        transactions_today: General.IntegerString,
        gas_used_today: %Schema{anyOf: [General.IntegerString, %Schema{type: :integer}]},
        gas_prices: %Schema{type: :object, nullable: true},
        gas_prices_update_in: %Schema{type: :integer, nullable: true},
        gas_price_updated_at: %Schema{type: :string, nullable: true},
        static_gas_price: %Schema{type: :number, nullable: true},
        market_cap: %Schema{type: :number, nullable: true},
        tvl: %Schema{type: :number, nullable: true},
        network_utilization_percentage: %Schema{type: :number, nullable: true}
      }
    }
    |> ChainTypeCustomizations.chain_type_fields()
    |> ChainTypeCustomizations.chain_identity_fields()
  )
end
