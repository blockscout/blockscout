defmodule BlockScoutWeb.Schemas.API.V2.Block.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.ChainTypeCustomizations, as: BlockChainTypeCustomizations
  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  @arbitrum_schema %Schema{
    type: :object,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      commitment_transaction_hash: %Schema{type: :string, nullable: true},
      confirmation_transaction_hash: %Schema{type: :string, nullable: true}
    }
  }

  @blob_gas_price_ethereum_schema %Schema{
    type: :integer,
    nullable: true
  }

  @burnt_blob_fees_ethereum_schema %Schema{
    type: :integer,
    nullable: true
  }

  @optimism_schema %Schema{
    type: :object,
    properties: %{
      number: %Schema{type: :integer, nullable: true},
      l1_timestamp: General.TimestampNullable,
      l1_transaction_hashes: %Schema{type: :array, items: General.FullHash, nullable: false},
      batch_data_container: %Schema{type: :string, nullable: false, enum: ["in_blob4844", "in_celestia", "in_calldata"]},
      blobs: %Schema{
        type: :array,
        items: %Schema{
          anyOf: [BlockChainTypeCustomizations.blob4844_schema(), BlockChainTypeCustomizations.celestia_schema()]
        },
        nullable: false
      }
    }
  }

  @zksync_schema %Schema{
    type: :object,
    properties: %{
      batch_number: %Schema{type: :integer, nullable: true},
      commit_transaction_hash: %Schema{type: :string, nullable: true},
      prove_transaction_hash: %Schema{type: :string, nullable: true},
      execute_transaction_hash: %Schema{type: :string, nullable: true}
    }
  }

  @zilliqa_schema %Schema{
    type: :object,
    properties: %{
      quorum_certificate: %Schema{type: :object, nullable: true},
      aggregate_quorum_certificate: %Schema{type: :object, nullable: true}
    }
  }

  @celo_schema BlockChainTypeCustomizations.celo_schema()

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
      :arbitrum ->
        schema
        |> put_in([:properties, :arbitrum], @arbitrum_schema)
        |> update_in([:required], &[:arbitrum | &1])

      :ethereum ->
        schema
        |> put_in([:properties, :blob_gas_price], @blob_gas_price_ethereum_schema)
        |> put_in([:properties, :burnt_blob_fees], @burnt_blob_fees_ethereum_schema)
        |> update_in([:required], &[:blob_gas_price, :burnt_blob_fees | &1])

      :optimism ->
        schema
        |> put_in([:properties, :optimism], @optimism_schema)

      :zksync ->
        schema
        |> put_in([:properties, :zksync], @zksync_schema)
        |> update_in([:required], &[:zksync | &1])

      :zilliqa ->
        schema
        |> put_in([:properties, :zilliqa], @zilliqa_schema)
        |> update_in([:required], &[:zilliqa | &1])

      :celo ->
        schema
        |> put_in([:properties, :celo], @celo_schema)
        |> update_in([:required], &[:celo | &1])

      _ ->
        schema
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block.Response.Common do
  @moduledoc """
  This module defines common schema fields for block responses.
  """
  def schema do
    alias BlockScoutWeb.Schemas.API.V2.Block.Common
    alias BlockScoutWeb.Schemas.API.V2.General
    alias OpenApiSpex.Schema

    %{
      type: :object,
      properties: %{
        burnt_fees: General.IntegerStringNullable,
        burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
        difficulty: General.IntegerStringNullable,
        withdrawals_count: %Schema{type: :integer, minimum: 0, nullable: true},
        beacon_deposits_count: %Schema{type: :integer, minimum: 0, nullable: true},
        blob_transactions_count: %Schema{type: :integer, minimum: 0, nullable: true},
        priority_fee: General.IntegerStringNullable,
        base_fee_per_gas: General.IntegerStringNullable,
        blob_gas_price: General.IntegerStringNullable,
        blob_gas_used: General.IntegerStringNullable,
        excess_blob_gas: General.IntegerStringNullable,
        uncles: %Schema{
          type: :array,
          items: General.FullHash,
          nullable: true
        },
        rewards: Common.rewards_schema()
      },
      required: [
        :burnt_fees,
        :burnt_fees_percentage,
        :priority_fee,
        :base_fee_per_gas,
        :rewards
      ]
    }
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block.Response do
  @moduledoc """
  This module defines the schema for block response from /api/v2/blocks/:hash_or_number.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.Response.{ChainTypeCustomizations, Common}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BlockResponse",
    description: "Block response",
    type: :object,
    allOf: [
      BlockScoutWeb.Schemas.API.V2.Block,
      struct(
        Schema,
        Common.schema()
        |> ChainTypeCustomizations.chain_type_fields()
      )
    ]
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.BlockInTheList.Response do
  @moduledoc """
  This module defines the schema for block response from /api/v2/blocks/:hash_or_number.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.Response.Common
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BlockInTheListResponse",
    description: "Block response",
    type: :object,
    allOf: [
      BlockScoutWeb.Schemas.API.V2.Block,
      struct(
        Schema,
        Common.schema()
      )
    ]
  })
end
