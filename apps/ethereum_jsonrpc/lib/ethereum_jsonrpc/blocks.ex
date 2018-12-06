defmodule EthereumJSONRPC.Blocks do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) from batch requests.
  """

  alias EthereumJSONRPC.{Block, Transport}

  @type elixir :: [Block.elixir()]
  @type params :: [Block.params()]
  @type t :: %__MODULE__{
          derived_params_list: [Block.derived_params()],
          errors: [Transport.error()]
        }

  defstruct derived_params_list: [],
            errors: []

  def requests(id_to_params, request) when is_map(id_to_params) and is_function(request, 1) do
    Enum.map(id_to_params, fn {id, params} ->
      params
      |> Map.put(:id, id)
      |> request.()
    end)
  end

  @spec from_responses(list(), map()) :: t()
  def from_responses(responses, id_to_params) when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&Block.from_response(&1, id_to_params))
    |> Enum.reduce(%__MODULE__{}, fn
      {:ok, block}, %__MODULE__{derived_params_list: derived_params_list} = acc ->
        %{acc | derived_params_list: [Block.derive_params(block) | derived_params_list]}

      {:error, error}, %__MODULE__{errors: errors} = acc ->
        %{acc | errors: [error | errors]}
    end)
  end
end
