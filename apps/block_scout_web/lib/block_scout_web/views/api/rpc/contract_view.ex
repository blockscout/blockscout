defmodule BlockScoutWeb.API.RPC.ContractView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.API.V2.Helper, as: APIV2Helper

  alias Explorer.Chain.{
    Address,
    InternalTransaction,
    SmartContract,
    Transaction
  }

  defguardp is_empty_string(input) when input == "" or input == nil

  def render("getcontractcreation.json", %{addresses: addresses}) do
    contracts = addresses |> Enum.map(&prepare_contract_creation_info/1) |> Enum.reject(&is_nil/1)

    RPCView.render("show.json", data: contracts)
  end

  def render("listcontracts.json", %{contracts: contracts}) do
    contracts = Enum.map(contracts, &prepare_contract/1)

    RPCView.render("show.json", data: contracts)
  end

  def render("getabi.json", %{abi: abi}) do
    RPCView.render("show.json", data: Jason.encode!(abi))
  end

  def render("getsourcecode.json", %{contract: contract}) do
    RPCView.render("show.json", data: [prepare_source_code_contract(contract)])
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  def render("verify.json", %{contract: contract}) do
    RPCView.render("show.json", data: prepare_source_code_contract(contract))
  end

  def render("show.json", %{result: result}) do
    RPCView.render("show.json", data: result)
  end

  defp prepare_source_code_contract(address) do
    contract = address.smart_contract || %{}

    optimization = Map.get(contract, :optimization, "")

    contract_output = %{
      "Address" => to_string(address.hash)
    }

    contract_output
    |> set_optimization_runs(contract, optimization)
    |> set_constructor_arguments(contract)
    |> set_external_libraries(contract)
    |> set_verified_contract_data(contract, address, optimization)
    |> set_proxy_info(contract)
    |> set_compiler_settings(contract)
  end

  defp set_compiler_settings(contract_output, contract) when contract == %{}, do: contract_output

  defp set_compiler_settings(contract_output, contract) do
    if is_nil(contract.compiler_settings) do
      contract_output
    else
      contract_output
      |> Map.put(:CompilerSettings, contract.compiler_settings)
    end
  end

  defp set_proxy_info(contract_output, contract) when contract == %{} do
    contract_output
  end

  defp set_proxy_info(contract_output, contract) do
    result =
      if contract.is_proxy do
        implementation_address_hash_string = List.first(contract.implementation_address_hash_strings)

        # todo: `ImplementationAddress` is kept for backward compatibility,
        # remove when clients unbound from these props
        contract_output
        |> Map.put_new(:ImplementationAddress, implementation_address_hash_string)
        |> Map.put_new(:ImplementationAddresses, contract.implementation_address_hash_strings)
      else
        contract_output
      end

    is_proxy_string = if contract.is_proxy, do: "true", else: "false"

    result
    |> Map.put_new(:IsProxy, is_proxy_string)
  end

  defp set_optimization_runs(contract_output, contract, optimization) do
    optimization_runs = Map.get(contract, :optimization_runs, "")

    if optimization && optimization != "" do
      contract_output
      |> Map.put_new(:OptimizationRuns, optimization_runs)
    else
      contract_output
    end
  end

  defp set_constructor_arguments(contract_output, %{constructor_arguments: arguments}) when is_empty_string(arguments),
    do: contract_output

  defp set_constructor_arguments(contract_output, %{constructor_arguments: arguments}) do
    contract_output
    |> Map.put_new(:ConstructorArguments, arguments)
  end

  defp set_constructor_arguments(contract_output, _), do: contract_output

  defp set_external_libraries(contract_output, contract) do
    external_libraries = Map.get(contract, :external_libraries, [])

    if Enum.empty?(external_libraries) do
      contract_output
    else
      external_libraries_without_id =
        Enum.map(external_libraries, fn %{name: name, address_hash: address_hash} ->
          %{"name" => name, "address_hash" => address_hash}
        end)

      contract_output
      |> Map.put_new(:ExternalLibraries, external_libraries_without_id)
    end
  end

  defp set_verified_contract_data(contract_output, contract, address, optimization) do
    contract_abi =
      if is_nil(address.smart_contract) do
        "Contract source code not verified"
      else
        Jason.encode!(contract.abi)
      end

    contract_optimization =
      case optimization do
        true ->
          "true"

        false ->
          "false"

        "" ->
          ""
      end

    if Map.equal?(contract, %{}) do
      contract_output
    else
      contract_output
      |> Map.put_new(:SourceCode, Map.get(contract, :contract_source_code, ""))
      |> Map.put_new(:ABI, contract_abi)
      |> Map.put_new(:ContractName, Map.get(contract, :name, ""))
      |> Map.put_new(:CompilerVersion, Map.get(contract, :compiler_version, ""))
      |> Map.put_new(:OptimizationUsed, contract_optimization)
      |> Map.put_new(:EVMVersion, Map.get(contract, :evm_version, ""))
      |> Map.put_new(:FileName, Map.get(contract, :file_path, "") || "")
      |> insert_additional_sources(address)
      |> add_zksync_info(contract)
    end
  end

  defp add_zksync_info(smart_contract_info, contract) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      smart_contract_info
      |> Map.put_new(:ZkCompilerVersion, Map.get(contract, :zk_compiler_version, ""))
    else
      smart_contract_info
    end
  end

  defp insert_additional_sources(output, address) do
    bytecode_twin_smart_contract = SmartContract.get_address_verified_bytecode_twin_contract(address)

    additional_sources_from_bytecode_twin =
      bytecode_twin_smart_contract && bytecode_twin_smart_contract.smart_contract_additional_sources

    additional_sources =
      if APIV2Helper.smart_contract_verified?(address),
        do: address.smart_contract.smart_contract_additional_sources,
        else: additional_sources_from_bytecode_twin

    additional_sources_array =
      if additional_sources,
        do:
          Enum.map(additional_sources, fn src ->
            %{
              Filename: src.file_name,
              SourceCode: src.contract_source_code
            }
          end),
        else: []

    if additional_sources_array == [],
      do: output,
      else: Map.put_new(output, :AdditionalSources, additional_sources_array)
  end

  defp prepare_contract(%Address{
         hash: hash,
         smart_contract: nil
       }) do
    %{
      "Address" => to_string(hash),
      "ABI" => "Contract source code not verified"
    }
  end

  defp prepare_contract(%Address{
         hash: hash,
         smart_contract: %SmartContract{} = contract
       }) do
    smart_contract_info =
      %{
        "Address" => to_string(hash),
        "ABI" => Jason.encode!(contract.abi),
        "ContractName" => contract.name,
        "CompilerVersion" => contract.compiler_version,
        "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
      }

    smart_contract_info
    |> merge_zksync_info(contract)
  end

  defp merge_zksync_info(smart_contract_info, contract) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      smart_contract_info
      |> Map.merge(%{"ZkCompilerVersion" => contract.zk_compiler_version})
    else
      smart_contract_info
    end
  end

  @spec prepare_contract_creation_info(Address.t()) :: %{binary() => binary()} | nil
  defp prepare_contract_creation_info(%Address{
         contract_creation_internal_transaction:
           %InternalTransaction{
             transaction: %Transaction{} = transaction
           } = internal_transaction
       }) do
    %{
      "contractAddress" => to_string(internal_transaction.created_contract_address_hash),
      "contractFactory" => to_string(internal_transaction.from_address_hash),
      "creationBytecode" => to_string(internal_transaction.init)
    }
    |> with_creation_transaction_info(transaction)
  end

  defp prepare_contract_creation_info(%Address{
         contract_creation_transaction: %Transaction{} = transaction
       }) do
    %{
      "contractAddress" => to_string(transaction.created_contract_address_hash),
      "contractFactory" => "",
      "creationBytecode" => to_string(transaction.input)
    }
    |> with_creation_transaction_info(transaction)
  end

  defp prepare_contract_creation_info(_), do: nil

  @spec with_creation_transaction_info(%{binary() => binary()}, Transaction.t()) ::
          %{binary() => binary()}
  defp with_creation_transaction_info(info, transaction) do
    unix_timestamp = DateTime.to_unix(transaction.block_timestamp, :second)

    %{
      "contractCreator" => to_string(transaction.from_address_hash),
      "txHash" => to_string(transaction.hash),
      "blockNumber" => to_string(transaction.block_number),
      "timestamp" => to_string(unix_timestamp)
    }
    |> Map.merge(info)
  end
end
