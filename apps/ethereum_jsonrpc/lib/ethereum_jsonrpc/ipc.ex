defmodule EthereumJSONRPC.IPC do
  use GenServer
  @moduledoc false

  import EthereumJSONRPC.HTTP, only: [standardize_response: 1]

  # Server

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.merge(opts, socket: nil))
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
        [socket: socket, path: _] = state
      ) do
    response =
      socket
      |> :gen_tcp.send(request)
      |> receive_response(socket, 500_000)

    {:reply, response, state}
  end

  # Client

  def request(pid, payload) do
    with {:ok, response} <- post(pid, Jason.encode!(payload)),
         {:ok, decoded_body} <- Jason.decode(response) do
      case decoded_body do
        %{"error" => error} ->
          {:error, error}

        result = [%{} | _] ->
          list =
            result
            |> Enum.reverse()
            |> List.flatten()
            |> Enum.map(&standardize_response/1)

          {:ok, list}

        result ->
          {:ok, Map.get(result, "result")}
      end
    else
      {:error, %Jason.DecodeError{data: ""}} -> {:error, :empty_response}
      {:error, error} -> {:error, {:invalid_json, error}}
    end
  end

  def json_rpc(payload, _opts) do
    :poolboy.transaction(:ipc_worker, fn pid -> request(pid, payload) end, 600_000)
  end
end
