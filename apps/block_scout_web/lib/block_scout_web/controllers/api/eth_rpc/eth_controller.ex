defmodule BlockScoutWeb.API.EthRPC.EthController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias Explorer.EthRPC

  def eth_request(%{body_params: %{"_json" => requests}} = conn, _) when is_list(requests) do
    case AccessHelpers.check_rate_limit(conn) do
      :ok ->
        responses = EthRPC.responses(requests)

        conn
        |> put_status(200)
        |> put_view(EthRPCView)
        |> render("responses.json", %{responses: responses})

      :rate_limit_reached ->
        AccessHelpers.handle_rate_limit_deny(conn)
    end
  end

  def eth_request(%{body_params: %{"_json" => request}} = conn, _) do
    case AccessHelpers.check_rate_limit(conn) do
      :ok ->
        [response] = EthRPC.responses([request])

        conn
        |> put_status(200)
        |> put_view(EthRPCView)
        |> render("response.json", %{response: response})

      :rate_limit_reached ->
        AccessHelpers.handle_rate_limit_deny(conn)
    end
  end

  def eth_request(conn, request) do
    case AccessHelpers.check_rate_limit(conn) do
      :ok ->
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

      :rate_limit_reached ->
        AccessHelpers.handle_rate_limit_deny(conn)
    end
  end
end
