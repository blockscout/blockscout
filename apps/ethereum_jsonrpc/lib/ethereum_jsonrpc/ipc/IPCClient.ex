defmodule EthereumJSONRPC.HTTP.IPCCLient do
  use GenServer
  @moduledoc false

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, Keyword.merge(state, socket: nil))
  end

  def init(state) do
    opts = [:binary, active: false, reuseaddr: true]

    response = :gen_tcp.connect({:local, state[:path]}, 0, opts)

    case response do
      {:ok, socket} -> {:ok, Keyword.put(state, :socket, socket)}
      {:error, reason} -> {:error, reason}
    end
  end

  def post(pid, request) do
    GenServer.call(pid, {:request, request})
  end

  def receive_response(data, socket, timeout, result \\ <<>>)

  def receive_response({:error, reason}, _socket, _timeout, _result) do
    {:error, reason}
  end

  def receive_response(:ok, socket, timeout, result) do
    with {:ok, response} <- :gen_tcp.recv(socket, 0, timeout) do
      new_result = result <> response

      if String.ends_with?(response, "\n") do
        {:ok, new_result}
      else
        receive_response(:ok, socket, timeout, new_result)
      end
    end
  end

  def receive_response(data, _socket, _timeout, _result) do
    {:error, data}
  end

  def handle_call(
        {:request, request},
        _from,
        [socket: socket, path: _, ipc_request_timeout: timeout] = state
      ) do
    response =
      socket
      |> :gen_tcp.send(request)
      |> receive_response(socket, timeout)

    {:reply, response, state}
  end
end
