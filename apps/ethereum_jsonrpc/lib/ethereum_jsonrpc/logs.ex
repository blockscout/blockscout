defmodule EthereumJSONRPC.Logs do
  @moduledoc """
  Collection of logs included in return from
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_gettransactionreceipt).
  """

  alias EthereumJSONRPC.{Log, Transport}

  @type elixir :: [Log.elixir()]
  @type t :: [Log.t()]

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Log.elixir_to_params/1)
  end

  @spec to_elixir(t) :: elixir
  def to_elixir(logs) when is_list(logs) do
    Enum.map(logs, &Log.to_elixir/1)
  end

  @spec request(id :: integer(), params :: map()) :: Transport.request()
  def request(id, params) when is_integer(id) and is_map(params) do
    EthereumJSONRPC.request(%{
      id: 0,
      method: "eth_getLogs",
      params: [params]
    })
  end

  def from_responses(responses) when is_list(responses) do
    responses
    |> reduce_responses()
    |> case do
      {:ok, logs} ->
        {
          :ok,
          logs
          |> to_elixir()
          |> elixir_to_params()
        }

      {:error, reasons} ->
        {:error, reasons}
    end
  end

  defp reduce_responses(responses) do
    responses
    |> Enum.reduce(
      {:ok, []},
      fn
        %{result: result}, {:ok, logs}
        when is_list(result) ->
          {:ok, result ++ logs}

        %{result: _}, {:error, _} = error ->
          error

        %{error: reason}, {:ok, _} ->
          {:error, [reason]}

        %{error: reason}, {:error, reasons}
        when is_list(reasons) ->
          {:error, [reason | reasons]}
      end
    )
  end
end
