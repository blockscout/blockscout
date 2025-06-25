defmodule BlockScoutWeb.API.EthRPC.EthController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.EthRPC

  def eth_request(%{body_params: %{"_json" => requests}} = conn, _) when is_list(requests) do
    eth_json_rpc_max_batch_size = Application.get_env(:block_scout_web, :api_rate_limit)[:eth_json_rpc_max_batch_size]

    if Enum.count(requests) <= eth_json_rpc_max_batch_size do
      responses = EthRPC.responses(requests)

      conn
      |> put_status(200)
      |> put_view(EthRPCView)
      |> render("responses.json", %{responses: responses})
    else
      conn
      |> put_status(413)
      |> put_view(RPCView)
      |> render(:error, %{:error => "Payload Too Large. Max batch size is #{eth_json_rpc_max_batch_size}"})
    end
  end

  def eth_request(%{body_params: %{"_json" => request}} = conn, _) do
    [response] = EthRPC.responses([request])

    conn
    |> put_status(200)
    |> put_view(EthRPCView)
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

    [response] = EthRPC.responses([decoded_request])

    conn
    |> put_status(200)
    |> put_view(EthRPCView)
    |> render("response.json", %{response: response})
  end
end
