defmodule BlockScoutWeb.SmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.SmartContract.{Reader, Writer}

  def index(conn, %{"hash" => address_hash_string, "type" => contract_type, "action" => action}) do
    address_options = [
      necessity_by_association: %{
        :smart_contract => :optional
      }
    ]

    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      functions =
        if action == "write" do
          if contract_type == "proxy" do
            Writer.write_functions_proxy(address_hash)
          else
            Writer.write_functions(address_hash)
          end
        else
          if contract_type == "proxy" do
            Reader.read_only_functions_proxy(address_hash)
          else
            Reader.read_only_functions(address_hash)
          end
        end

      contract_abi = Poison.encode!(address.smart_contract.abi)

      implementation_abi =
        if contract_type == "proxy" do
          address.hash
          |> Chain.get_implementation_abi_from_proxy(address.smart_contract.abi)
          |> Poison.encode!()
        else
          []
        end

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_functions.html",
        read_only_functions: functions,
        address: address,
        contract_abi: contract_abi,
        implementation_abi: implementation_abi,
        contract_type: contract_type
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

  def index(conn, _), do: not_found(conn)

  def show(conn, params) do
    address_options = [
      necessity_by_association: %{
        :contracts_creation_internal_transaction => :optional,
        :names => :optional,
        :smart_contract => :optional,
        :token => :optional,
        :contracts_creation_transaction => :optional
      }
    ]

    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(params["id"]),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      contract_type = if Chain.is_proxy_contract?(address.smart_contract.abi), do: :proxy, else: :regular

      outputs =
        Reader.query_function(
          address_hash,
          %{name: params["function_name"], args: params["args"]},
          contract_type
        )

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

      :not_found ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end
end
