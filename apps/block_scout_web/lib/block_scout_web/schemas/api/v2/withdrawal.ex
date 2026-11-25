# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Withdrawal.ChainTypeCustomizations do
  @moduledoc false
  alias BlockScoutWeb.Schemas.API.V2.General
  alias BlockScoutWeb.Schemas.Helper

  use Utils.RuntimeEnvHelper, chain_type: [:explorer, :chain_type]

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   On Bera chain type `index` and `validator_index` can be equal to the max
   `uint64` value (the EVM inflation withdrawal), so they are rendered as
   strings.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  def chain_type_fields(schema) do
    case chain_type() do
      :bera ->
        Helper.extend_schema(schema,
          properties: %{
            index: General.IntegerString,
            validator_index: General.IntegerString
          }
        )

      _ ->
        schema
    end
  end

  @doc """
   Returns the names of the paging parameters of the withdrawals list endpoints.

   On Bera chain type the withdrawal index is not unique, so the withdrawals
   are paginated by the block number and the index.
  """
  @spec paging_params_names() :: [String.t()]
  def paging_params_names do
    case chain_type() do
      :bera -> ["block_number", "index"]
      _ -> ["index"]
    end
  end

  @doc """
   Returns an example of the next page params of the withdrawals list endpoints.
  """
  @spec next_page_params_example() :: map()
  def next_page_params_example do
    case chain_type() do
      :bera -> %{"block_number" => 29_258_250, "index" => "18446744073709551615"}
      _ -> %{"index" => 88_192_653}
    end
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Withdrawal do
  @moduledoc """
  This module defines the schema for the Withdrawal struct.
  """
  require OpenApiSpex
  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias BlockScoutWeb.Schemas.API.V2.Withdrawal.ChainTypeCustomizations
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    %{
      title: "BeaconWithdrawal",
      type: :object,
      properties: %{
        index: %Schema{type: :integer, nullable: false},
        validator_index: %Schema{type: :integer, nullable: false},
        amount: General.IntegerString,
        block_number: %Schema{type: :integer, nullable: false},
        receiver: Address,
        timestamp: General.Timestamp
      },
      required: [
        :index,
        :validator_index,
        :amount
      ],
      additionalProperties: false
    }
    |> ChainTypeCustomizations.chain_type_fields()
  )
end
