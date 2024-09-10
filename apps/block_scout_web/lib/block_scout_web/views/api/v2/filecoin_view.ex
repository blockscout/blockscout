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
end
