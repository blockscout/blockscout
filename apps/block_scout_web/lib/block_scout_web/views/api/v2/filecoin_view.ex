defmodule BlockScoutWeb.API.V2.FilecoinView do
  @moduledoc """
  View functions for rendering Filecoin-related data in JSON format.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :filecoin do
    # TODO: remove when https://github.com/elixir-lang/elixir/issues/13975 comes to elixir release
    alias Explorer.Chain, warn: false
    alias Explorer.Chain.Address, warn: false

    @api_true [api?: true]

    @doc """
    Extends the json output with a sub-map containing information related to
    Filecoin native addressing.
    """
    @spec extend_address_json_response(map(), Address.t()) :: map()
    def extend_address_json_response(
          result,
          %Address{filecoin_id: filecoin_id, filecoin_robust: filecoin_robust, filecoin_actor_type: filecoin_actor_type}
        ) do
      Map.put(result, :filecoin, %{
        id: filecoin_id,
        robust: filecoin_robust,
        actor_type: filecoin_actor_type
      })
    end

    @spec preload_and_put_filecoin_robust_address(map(), %{
            optional(:address_hash) => String.t() | nil,
            optional(:field_prefix) => String.t() | nil,
            optional(any) => any
          }) ::
            map()
    def preload_and_put_filecoin_robust_address(result, %{address_hash: address_hash} = params) do
      address = address_hash && Address.get(address_hash, @api_true)

      put_filecoin_robust_address(result, Map.put(params, :address, address))
    end

    def preload_and_put_filecoin_robust_address(result, _params) do
      result
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
    @spec put_filecoin_robust_address(map(), %{
            required(:address) => Address.t(),
            required(:field_prefix) => String.t() | nil,
            optional(any) => any
          }) :: map()
    def put_filecoin_robust_address(result, %{
          address: %Address{filecoin_robust: filecoin_robust},
          field_prefix: field_prefix
        }) do
      put_filecoin_robust_address_internal(result, filecoin_robust, field_prefix)
    end

    def put_filecoin_robust_address(result, %{field_prefix: field_prefix}) do
      put_filecoin_robust_address_internal(result, nil, field_prefix)
    end

    defp put_filecoin_robust_address_internal(result, filecoin_robust, field_prefix) do
      field_name = (field_prefix && "#{field_prefix}_filecoin_robust_address") || "filecoin_robust_address"
      Map.put(result, field_name, filecoin_robust)
    end

    @doc """
    Preloads and inserts Filecoin robust addresses into the search results.

    ## Parameters

      - search_results: The search results that need to be enriched with Filecoin robust addresses.

    ## Returns

      - The search results with preloaded Filecoin robust addresses.
    """
    @spec preload_and_put_filecoin_robust_address_to_search_results(list()) :: list()
    def preload_and_put_filecoin_robust_address_to_search_results(search_results) do
      addresses_map =
        search_results
        |> Enum.map(& &1["address_hash"])
        |> Enum.reject(&is_nil/1)
        |> Chain.hashes_to_addresses(@api_true)
        |> Enum.into(%{}, &{to_string(&1.hash), &1})

      search_results
      |> Enum.map(fn
        %{"address_hash" => address_hash} = result when not is_nil(address_hash) ->
          address = addresses_map[String.downcase(address_hash)]
          put_filecoin_robust_address(result, %{address: address, field_prefix: nil})

        other ->
          other
      end)
    end
  end
end

# end
