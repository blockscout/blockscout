defmodule EthereumJSONRPC.IPC do
  use GenServer
  @moduledoc false

  # Server

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

  # Client

  def json_rpc(pid, payload, _opts) do
    with {:ok, response} <- post(pid, payload),
         {:ok, decoded_body} <- Jason.decode(response) do
      case decoded_body do
        %{"error" => error} -> {:error, error}
        result = [%{} | _] -> {:ok, format_batch(result)}
        result -> {:ok, Map.get(result, "result")}
      end
    else
      {:error, %Jason.DecodeError{data: ""}} -> {:error, :empty_response}
      {:error, error} -> {:error, {:invalid_json, error}}
      {:error, error} -> {:error, error}
    end
  end

  defp format_batch(list) do
    list
    |> Enum.sort(fn %{"id" => id1}, %{"id" => id2} ->
      id1 <= id2
    end)
    |> Enum.map(fn %{"result" => result} ->
      result
    end)
  end
end
