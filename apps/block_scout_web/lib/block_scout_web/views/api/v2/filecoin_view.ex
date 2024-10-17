if Application.compile_env(:explorer, :chain_type) == :filecoin do
  defmodule BlockScoutWeb.API.V2.FilecoinView do
    @moduledoc """
    View functions for rendering Filecoin-related data in JSON format.
    """

    alias Explorer.Chain.Address

    @doc """
    Extends the json output with a sub-map containing information related to
    Filecoin native addressing.
    """
    @spec extend_address_json_response(map(), Address.t()) :: map()
    def extend_address_json_response(result, %Address{} = address) do
      filecoin_id = Map.get(address, :filecoin_id)
      filecoin_robust = Map.get(address, :filecoin_robust)
      filecoin_actor_type = Map.get(address, :filecoin_actor_type)

      is_fetched =
        Enum.all?(
          [
            filecoin_id,
            filecoin_robust,
            filecoin_actor_type
          ],
          &(not is_nil(&1))
        )

      Map.put(result, :filecoin, %{
        is_fetched: is_fetched,
        id: filecoin_id,
        robust: filecoin_robust,
        actor_type: filecoin_actor_type
      })
    end

    @spec preload_and_put_filecoin_robust_address(map(), map()) :: map()
    def preload_and_put_filecoin_robust_address(result, %{address_hash: address_hash} = params) do
      case Address.get(address_hash) do
        nil -> result
        address -> put_filecoin_robust_address(result, Map.put(params, :address, address))
      end
    end

    @doc """
    Adds a Filecoin robust address to the given result.

    ## Parameters

      - result: The initial result to which the Filecoin robust address will be added.
      - opts: A map containing the following keys:
        - `:address` - A struct containing the `filecoin_robust` address.
        - `:field_prefix` - A prefix to be used for the field name in the result.

    ## Returns

    The updated result with the Filecoin robust address added.
    """
    @spec put_filecoin_robust_address(map(), map()) :: map()
    def put_filecoin_robust_address(result, %{
          address: %Address{filecoin_robust: filecoin_robust},
          field_prefix: field_prefix
        }) do
      field_name = (field_prefix && "#{field_prefix}_filecoin_robust_address") || "filecoin_robust_address"
      Map.put(result, field_name, filecoin_robust)
    end

    def put_filecoin_robust_address(result, _) do
      result
    end
  end
end
