# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Transaction.Response.ChainTypeCustomizations do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Optimism.InteropMessage
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
    case Application.get_env(:explorer, :chain_type) do
      :optimism ->
        schema
        |> Helper.extend_schema(
          properties: %{op_interop_messages: %Schema{type: :array, items: InteropMessage, nullable: false}}
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
