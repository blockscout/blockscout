defmodule EthereumJSONRPC.WebSocket.Socket.Receiver do
  @moduledoc """
  Receives WebSocket messages with `Socket.Web.recv` and send non-ping/pong messages on to `EthereumJSONRPC.WebSocket.Socket`
  """

  @enforce_keys ~w(parent socket_web)a
  defstruct fragments_type: nil,
            fragments: [],
            parent: nil,
            socket_web: nil

  def spawn_link(named_arguments) do
    spawn_link(__MODULE__, :loop, [struct!(__MODULE__, named_arguments)])
  end

  @doc false
  def loop(%__MODULE__{socket_web: socket_web} = state) do
    loop(state, Socket.Web.recv(socket_web))
  end

  # start of fragment
  defp loop(state, {:ok, {:fragmented, type, fragment}}) when type in ~w(binary text)a do
    loop(%__MODULE__{state | fragments_type: type, fragments: [fragment]})
  end

  # middle of fragment
  defp loop(%__MODULE__{fragments: fragments} = state, {:ok, {:fragmented, :continuation, fragment}}) do
    loop(%__MODULE__{state | fragments: [fragments | fragment]})
  end

  # end of fragment
  defp loop(
         %__MODULE__{fragments_type: fragments_type, fragments: fragments, parent: parent} = state,
         {:ok, {:fragmented, :end, fragment}}
       ) do
    GenServer.cast(parent, {fragments_type, IO.iodata_to_binary([fragments | fragment])})
    loop(%__MODULE__{state | fragments_type: nil, fragments: []})
  end

  defp loop(%__MODULE__{parent: parent} = state, {:ok, {:binary, _} = binary}) do
    GenServer.cast(parent, binary)
    loop(state)
  end

  defp loop(%__MODULE__{parent: parent} = state, {:ok, {:text, _} = text}) do
    GenServer.cast(parent, text)
    loop(state)
  end

  defp loop(%__MODULE__{socket_web: socket_web} = state, {:ok, {:ping, data}}) do
    Socket.Web.send!(socket_web, {:pong, data})
    loop(state)
  end

  defp loop(%__MODULE__{parent: parent} = state, {:ok, {:pong, _data} = pong}) do
    GenServer.cast(parent, pong)
    loop(state)
  end

  defp loop(%__MODULE__{parent: parent}, {:ok, :close = close}) do
    GenServer.cast(parent, close)
  end

  defp loop(%__MODULE__{parent: parent}, {:ok, {:close, _code, _data} = close}) do
    GenServer.cast(parent, close)
  end

  defp loop(%__MODULE__{parent: parent}, {:error, _reason} = error) do
    GenServer.cast(parent, error)
  end
end
