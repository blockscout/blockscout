defmodule BlockScoutWeb.API.RPC.EthController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Wei

  def eth_request(%{body_params: %{"_json" => requests}} = conn, _) when is_list(requests) do
    responses = responses(requests)

    conn
    |> put_status(200)
    |> render("responses.json", %{responses: responses})
  end

  def eth_request(%{body_params: %{"_json" => request}} = conn, _) do
    [response] = responses([request])

    conn
    |> put_status(200)
    |> render("response.json", %{response: response})
  end

  def eth_request(conn, request) do
    # In the case that the JSON body is sent up w/o a json content type,
    # Phoenix encodes it as a single key value pair, with the value being
    # nil and the body being the key (as in a CURL request w/ no content type header)
    decoded_request =
      with [{single_key, nil}] <- Map.to_list(request),
           {:ok, decoded} <- Jason.decode(single_key) do
        decoded
      else
        _ -> request
      end

    [response] = responses([decoded_request])

    conn
    |> put_status(200)
    |> render("response.json", %{response: response})
  end

  defp responses(requests) do
    Enum.map(requests, fn request ->
      with {:id, {:ok, id}} <- {:id, Map.fetch(request, "id")},
           {:request, {:ok, result}} <- {:request, do_eth_request(request)} do
        format_success(result, id)
      else
        {:id, :error} -> format_error("id is a required field", 0)
        {:request, {:error, message}} -> format_error(message, Map.get(request, "id"))
      end
    end)
  end

  defp format_success(result, id) do
    %{result: result, id: id}
  end

  defp format_error(message, id) do
    %{error: message, id: id}
  end

  defp do_eth_request(%{"jsonrpc" => rpc_version}) when rpc_version != "2.0" do
    {:error, "invalid rpc version"}
  end

  defp do_eth_request(%{"jsonrpc" => "2.0", "method" => method, "params" => params})
       when is_list(params) do
    with {:ok, action} <- get_action(method),
         true <- :erlang.function_exported(__MODULE__, action, Enum.count(params)) do
      apply(__MODULE__, action, params)
    else
      _ ->
        {:error, "Action not found."}
    end
  end

  defp do_eth_request(%{"params" => _params, "method" => _}) do
    {:error, "Invalid params. Params must be a list."}
  end

  defp do_eth_request(_) do
    {:error, "Method, params, and jsonrpc, are all required parameters."}
  end

  def eth_get_balance(address_param, block_param \\ nil) do
    with {:address, {:ok, address}} <- {:address, Chain.string_to_address_hash(address_param)},
         {:block, {:ok, block}} <- {:block, block_param(block_param)},
         {:balance, {:ok, balance}} <- {:balance, Chain.get_balance_as_of_block(address, block)} do
      {:ok, Wei.hex_format(balance)}
    else
      {:address, :error} ->
        {:error, "Query parameter 'address' is invalid"}

      {:block, :error} ->
        {:error, "Query parameter 'block' is invalid"}

      {:balance, {:error, :not_found}} ->
        {:error, "Balance not found"}
    end
  end

  defp get_action("eth_getBalance"), do: {:ok, :eth_get_balance}
  defp get_action(_), do: :error

  defp block_param("latest"), do: {:ok, :latest}
  defp block_param("earliest"), do: {:ok, :earliest}
  defp block_param("pending"), do: {:ok, :pending}

  defp block_param(string_integer) when is_bitstring(string_integer) do
    case Integer.parse(string_integer) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp block_param(nil), do: {:ok, :latest}
  defp block_param(_), do: :error
end
