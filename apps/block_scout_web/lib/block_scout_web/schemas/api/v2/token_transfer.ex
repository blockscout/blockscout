defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer.TransactionHashCustomization do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias BlockScoutWeb.Schemas.API.V2.General

  def schema do
    case Application.get_env(:explorer, :chain_type) do
      :celo ->
        General.FullHashNullable

      _ ->
        General.FullHash
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer do
  @moduledoc """
  Schema for token transfer
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}

  alias BlockScoutWeb.Schemas.API.V2.TokenTransfer.{
    Total,
    TotalERC1155,
    TotalERC721,
    TransactionHashCustomization
  }

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      transaction_hash: TransactionHashCustomization.schema(),
      from: Address,
      to: Address,
      total: %Schema{
        anyOf: [
          TotalERC721,
          TotalERC1155,
          Total
        ],
        nullable: true
      },
      token: Token,
      type: %Schema{type: :string, enum: ["token_burning", "token_minting", "token_spawning", "token_transfer"]},
      timestamp: General.TimestampNullable,
      method: General.MethodNameNullable,
      block_hash: General.FullHash,
      block_number: %Schema{type: :integer, nullable: false},
      log_index: %Schema{type: :integer, nullable: false},
      token_type: Token.Type
    },
    required: [
      :transaction_hash,
      :from,
      :to,
      :total,
      :token,
      :type,
      :timestamp,
      :method,
      :block_hash,
      :block_number,
      :log_index,
      :token_type
    ]
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer.TotalERC721 do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, TokenInstance}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      token_id: General.IntegerStringNullable,
      token_instance: %Schema{type: :object, anyOf: [TokenInstance], nullable: true}
    },
    required: [:token_id, :token_instance]
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer.TotalERC1155 do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{General, TokenInstance}
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      token_id: General.IntegerStringNullable,
      value: General.IntegerStringNullable,
      decimals: General.IntegerStringNullable,
      token_instance: %Schema{type: :object, anyOf: [TokenInstance], nullable: true}
    },
    required: [:token_id, :value, :decimals, :token_instance]
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.TokenTransfer.Total do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      value: General.IntegerStringNullable,
      decimals: General.IntegerStringNullable
    },
    required: [:value, :decimals]
  })
end
