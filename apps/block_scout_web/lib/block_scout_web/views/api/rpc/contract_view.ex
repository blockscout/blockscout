defmodule BlockScoutWeb.API.RPC.ContractView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.{Address, DecompiledSmartContract, SmartContract}

  defguardp is_empty_string(input) when input == "" or input == nil

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

  defp prepare_source_code_contract(nil) do
    %{
      "Address" => "",
      "SourceCode" => "",
      "ABI" => "Contract source code not verified",
      "ContractName" => "",
      "CompilerVersion" => "",
      "DecompiledSourceCode" => "",
      "DecompilerVersion" => decompiler_version(nil),
      "OptimizationUsed" => "",
      "OptimizationRuns" => "",
      "EVMVersion" => "",
      "ConstructorArguments" => "",
      "ExternalLibraries" => ""
    }
  end

  defp prepare_source_code_contract(address) do
    decompiled_smart_contract = latest_decompiled_smart_contract(address.decompiled_smart_contracts)
    contract = address.smart_contract || %{}

    optimization = Map.get(contract, :optimization, "")

    contract_output = %{
      "Address" => to_string(address.hash)
    }

    contract_output
    |> set_decompiled_contract_data(decompiled_smart_contract)
    |> set_optimization_runs(contract, optimization)
    |> set_constructor_arguments(contract)
    |> set_external_libraries(contract)
    |> set_verified_contract_data(contract, address, optimization)
  end

  defp set_decompiled_contract_data(contract_output, decompiled_smart_contract) do
    if decompiled_smart_contract do
      contract_output
      |> Map.put_new(:DecompiledSourceCode, decompiled_source_code(decompiled_smart_contract))
      |> Map.put_new(:DecompilerVersion, decompiler_version(decompiled_smart_contract))
    else
      contract_output
    end
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

    if Enum.count(external_libraries) > 0 do
      external_libraries_without_id =
        Enum.map(external_libraries, fn %{name: name, address_hash: address_hash} ->
          %{"name" => name, "address_hash" => address_hash}
        end)

      contract_output
      |> Map.put_new(:ExternalLibraries, external_libraries_without_id)
    else
      contract_output
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
    end
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
    %{
      "Address" => to_string(hash),
      "ABI" => Jason.encode!(contract.abi),
      "ContractName" => contract.name,
      "CompilerVersion" => contract.compiler_version,
      "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
    }
  end

  defp latest_decompiled_smart_contract([]), do: nil

  defp latest_decompiled_smart_contract(contracts) do
    Enum.max_by(contracts, fn contract -> DateTime.to_unix(contract.inserted_at) end)
  end

  defp decompiled_source_code(nil), do: "Contract source code not decompiled."

  defp decompiled_source_code(%DecompiledSmartContract{decompiled_source_code: decompiled_source_code}) do
    decompiled_source_code
  end

  defp decompiler_version(nil), do: ""
  defp decompiler_version(%DecompiledSmartContract{decompiler_version: decompiler_version}), do: decompiler_version
end
