defmodule BlockScoutWeb.API.RPC.ContractView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.{Address, DecompiledSmartContract, SmartContract}

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
      "OptimizationUsed" => ""
    }
  end

  defp prepare_source_code_contract(address) do
    decompiled_smart_contract = latest_decompiled_smart_contract(address.decompiled_smart_contracts)
    contract = address.smart_contract || %{}

    contract_abi =
      if is_nil(address.smart_contract) do
        "Contract source code not verified"
      else
        Jason.encode!(contract.abi)
      end

    contract_optimization =
      case Map.get(contract, :optimization, "") do
        true ->
          "1"

        false ->
          "0"

        "" ->
          ""
      end

    %{
      "Address" => to_string(address.hash),
      "SourceCode" => Map.get(contract, :contract_source_code, ""),
      "ABI" => contract_abi,
      "ContractName" => Map.get(contract, :name, ""),
      "DecompiledSourceCode" => decompiled_source_code(decompiled_smart_contract),
      "DecompilerVersion" => decompiler_version(decompiled_smart_contract),
      "CompilerVersion" => Map.get(contract, :compiler_version, ""),
      "OptimizationUsed" => contract_optimization
    }
  end

  defp prepare_contract(%Address{
         hash: hash,
         smart_contract: nil
       }) do
    %{
      "Address" => to_string(hash),
      "ABI" => "Contract source code not verified",
      "ContractName" => "",
      "CompilerVersion" => "",
      "OptimizationUsed" => ""
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
