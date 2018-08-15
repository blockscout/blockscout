defmodule BlockScoutWeb.SmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.SmartContract.Reader

  def index(conn, %{"hash" => address_hash_string}) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash) do
      read_only_functions = Reader.read_only_functions(address_hash)

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_functions.html",
        read_only_functions: read_only_functions,
        address: address
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  def show(conn, params) do
    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(params["id"]),
         outputs =
           Reader.query_function(
             address_hash,
             %{name: params["function_name"], args: params["args"]}
           ) do
      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_function_response.html",
        function_name: params["function_name"],
        outputs: outputs
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  defp ajax?(conn) do
    case get_req_header(conn, "x-requested-with") do
      [value] -> value in ["XMLHttpRequest", "xmlhttprequest"]
      [] -> false
    end
  end
end
