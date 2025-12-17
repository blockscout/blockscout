defmodule BlockScoutWeb.Schemas.API.V2.General.Implementation.ChainTypeCustomizations do
  @moduledoc false
  import BlockScoutWeb.Schemas.API.V2.Address.ChainTypeCustomizations, only: [filecoin_robust_address_schema: 0]

  @doc """
   Applies chain-specific field customizations to the given schema based on the configured chain type.

   ## Parameters
   - `schema`: The base schema map to be customized

   ## Returns
   - The schema map with chain-specific properties added based on the current chain type configuration
  """
  @spec chain_type_fields(map()) :: map()
  def chain_type_fields(schema) do
    alias BlockScoutWeb.Schemas.Helper

    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        schema
        |> Helper.extend_schema(
          properties: %{
            filecoin_robust_address: filecoin_robust_address_schema()
          },
          required: [:filecoin_robust_address]
        )

      _ ->
        schema
    end
  end
end
