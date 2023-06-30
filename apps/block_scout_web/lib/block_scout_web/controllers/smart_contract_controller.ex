defmodule BlockScoutWeb.SmartContractController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AddressView
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{Reader, Writer}

  import Explorer.SmartContract.Solidity.Verifier, only: [parse_boolean: 1]

  @burn_address "0x0000000000000000000000000000000000000000"

  def index(conn, %{"hash" => address_hash_string, "type" => contract_type, "action" => action} = params) do
    address_options = [
      necessity_by_association: %{
        :smart_contract => :optional
      }
    ]

    is_custom_abi = parse_boolean(params["is_custom_abi"])

    with {:contract_interaction_disabled, false} <-
           {:contract_interaction_disabled, write_contract_api_disabled?(action)},
         true <- ajax?(conn),
         {:custom_abi, false} <- {:custom_abi, is_custom_abi},
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      implementation_address_hash_string =
        if contract_type == "proxy" do
          address.smart_contract
          |> SmartContract.get_implementation_address_hash()
          |> Tuple.to_list()
          |> List.first() || @burn_address
        else
          @burn_address
        end

      functions =
        if action == "write" do
          if contract_type == "proxy" do
            Writer.write_functions_proxy(implementation_address_hash_string)
          else
            Writer.write_functions(address.smart_contract)
          end
        else
          if contract_type == "proxy" do
            Reader.read_only_functions_proxy(address_hash, implementation_address_hash_string, nil)
          else
            Reader.read_only_functions(address.smart_contract, address_hash, params["from"])
          end
        end

      read_functions_required_wallet =
        if action == "read" do
          if contract_type == "proxy" do
            Reader.read_functions_required_wallet_proxy(implementation_address_hash_string)
          else
            Reader.read_functions_required_wallet(address.smart_contract)
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
      {:custom_abi, true} ->
        custom_abi_render(conn, params)

      :error ->
        unprocessable_entity(conn)

      {:contract_interaction_disabled, true} ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  def index(conn, _), do: not_found(conn)

  defp custom_abi_render(conn, %{"hash" => address_hash_string, "type" => contract_type, "action" => action} = params) do
    with custom_abi <- AddressView.fetch_custom_abi(conn, address_hash_string),
         false <- is_nil(custom_abi),
         abi <- custom_abi.abi,
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      functions =
        if action == "write" do
          Writer.filter_write_functions(abi)
        else
          Reader.read_only_functions_from_abi_with_sender(abi, address_hash, params["from"])
        end

      read_functions_required_wallet =
        if action == "read" do
          Reader.read_functions_required_wallet_from_abi(abi)
        else
          []
        end

      contract_abi = Poison.encode!(abi)

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_functions.html",
        read_functions_required_wallet: read_functions_required_wallet,
        read_only_functions: functions,
        address: %{hash: address_hash},
        custom_abi: true,
        contract_abi: contract_abi,
        implementation_address: @burn_address,
        implementation_abi: [],
        contract_type: contract_type,
        action: action
      )
    else
      :error ->
        unprocessable_entity(conn)

      _ ->
        not_found(conn)
    end
  end

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

    custom_abi =
      if parse_boolean(params["is_custom_abi"]), do: AddressView.fetch_custom_abi(conn, params["id"]), else: nil

    with true <- ajax?(conn),
         {:ok, address_hash} <- Chain.string_to_address_hash(params["id"]),
         {:ok, address} <- Chain.find_contract_address(address_hash, address_options, true) do
      contract_type = if params["type"] == "proxy", do: :proxy, else: :regular

      args =
        if is_nil(params["args_count"]) do
          # we should convert: %{"0" => _, "1" => _} to [_, _]
          params["args"] |> convert_map_to_array()
        else
          {args_count, _} = Integer.parse(params["args_count"])

          if args_count < 1,
            do: [],
            else: for(x <- 0..(args_count - 1), do: params["arg_" <> to_string(x)] |> convert_map_to_array())
        end

      %{output: outputs, names: names} =
        if custom_abi do
          Reader.query_function_with_names_custom_abi(
            address_hash,
            %{method_id: params["method_id"], args: args},
            params["from"],
            custom_abi.abi
          )
        else
          Reader.query_function_with_names(
            address_hash,
            %{method_id: params["method_id"], args: args},
            contract_type,
            params["from"],
            address.smart_contract && address.smart_contract.abi,
            true
          )
        end

      conn
      |> put_status(200)
      |> put_layout(false)
      |> render(
        "_function_response.html",
        function_name: params["function_name"],
        method_id: params["method_id"],
        outputs: outputs,
        names: names,
        smart_contract_address: address_hash
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

  defp convert_map_to_array(map) do
    if is_turned_out_array?(map) do
      map |> Map.values() |> try_to_map_elements()
    else
      try_to_map_elements(map)
    end
  end

  defp try_to_map_elements(values) do
    if Enumerable.impl_for(values) do
      Enum.map(values, &convert_map_to_array/1)
    else
      values
    end
  end

  defp is_turned_out_array?(map) when is_map(map), do: Enum.all?(Map.keys(map), &is_integer?/1)

  defp is_turned_out_array?(_), do: false

  defp is_integer?(string) when is_binary(string) do
    case string |> String.trim() |> Integer.parse() do
      {_, ""} ->
        true

      _ ->
        false
    end
  end

  defp is_integer?(integer) when is_integer(integer), do: true

  defp is_integer?(_), do: false

  defp write_contract_api_disabled?(action), do: AddressView.contract_interaction_disabled?() && action == "write"
end
