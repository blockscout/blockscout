defmodule BlockScoutWeb.SmartContractController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.SmartContract.{Reader, Writer}

  @burn_address "0x0000000000000000000000000000000000000000"

  def index(conn, %{"hash" => address_hash_string, "type" => contract_type, "action" => action}) do
    address_options = [
      necessity_by_association: %{
        :smart_contract => :optional
      }
    ]

    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      implementation_address_hash_string =
        if contract_type == "proxy" do
          Chain.get_implementation_address_hash(address.hash, address.smart_contract.abi) ||
            @burn_address
        else
          @burn_address
        end

      functions =
        if action == "write" do
          if contract_type == "proxy" do
            Writer.write_functions_proxy(implementation_address_hash_string)
          else
            Writer.write_functions(address_hash)
          end
        else
          if contract_type == "proxy" do
            Reader.read_only_functions_proxy(address_hash, implementation_address_hash_string)
          else
            Reader.read_only_functions(address_hash)
          end
        end

      read_functions_required_wallet =
        if action == "read" do
          if contract_type == "proxy" do
            Reader.read_functions_required_wallet_proxy(implementation_address_hash_string)
          else
            Reader.read_functions_required_wallet(address_hash)
          end
        else
          []
        end

      contract_abi = Poison.encode!(address.smart_contract.abi)

      implementation_abi =
        if contract_type == "proxy" do
          implementation_address_hash_string
          |> Chain.get_implementation_abi()
          |> Poison.encode!()
        else
          []
        end

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_functions.html",
        read_functions_required_wallet: read_functions_required_wallet,
        read_only_functions: functions,
        address: address,
        contract_abi: contract_abi,
        implementation_address: implementation_address_hash_string,
        implementation_abi: implementation_abi,
        contract_type: contract_type,
        action: action
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
      contract_type = if Chain.proxy_contract?(address.hash, address.smart_contract.abi), do: :proxy, else: :regular

      %{output: outputs, names: names} =
        Reader.query_function_with_names(
          address_hash,
          %{method_id: params["method_id"], args: params["args"]},
          contract_type,
          params["function_name"]
        )

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_function_response.html",
        function_name: params["function_name"],
        method_id: params["method_id"],
        outputs: outputs,
        names: names
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
