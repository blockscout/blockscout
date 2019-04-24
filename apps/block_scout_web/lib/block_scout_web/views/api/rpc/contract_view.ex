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

  def render("getsourcecode.json", %{contract: contract, address_hash: address_hash}) do
    RPCView.render("show.json", data: [prepare_source_code_contract(contract, address_hash)])
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  def render("verify.json", %{contract: contract, address_hash: address_hash}) do
    RPCView.render("show.json", data: prepare_source_code_contract(contract, address_hash))
  end

  defp prepare_source_code_contract(nil, address_hash) do
    %{
      "Address" => to_string(address_hash),
      "SourceCode" => "",
      "ABI" => "Contract source code not verified",
      "ContractName" => "",
      "CompilerVersion" => "",
      "DecompiledSourceCode" => "",
      "DecompilerVersion" => "",
      "OptimizationUsed" => ""
    }
  end

  defp prepare_source_code_contract(contract, _) do
    decompiled_smart_contract = latest_decompiled_smart_contract(contract.decompiled_smart_contracts)

    %{
      "Address" => to_string(contract.address_hash),
      "SourceCode" => contract.contract_source_code,
      "ABI" => Jason.encode!(contract.abi),
      "ContractName" => contract.name,
      "DecompiledSourceCode" => decompiled_source_code(decompiled_smart_contract),
      "DecompilerVersion" => decompiler_version(decompiled_smart_contract),
      "CompilerVersion" => contract.compiler_version,
      "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
    }
  end

  defp prepare_contract(%Address{
         hash: hash,
         smart_contract: nil,
         decompiled_smart_contracts: decompiled_smart_contracts
       }) do
    decompiled_smart_contract = latest_decompiled_smart_contract(decompiled_smart_contracts)

    %{
      "Address" => to_string(hash),
      "SourceCode" => "",
      "ABI" => "Contract source code not verified",
      "ContractName" => "",
      "DecompiledSourceCode" => decompiled_source_code(decompiled_smart_contract),
      "DecompilerVersion" => decompiler_version(decompiled_smart_contract),
      "CompilerVersion" => "",
      "OptimizationUsed" => ""
    }
  end

  defp prepare_contract(%Address{
         hash: hash,
         smart_contract: %SmartContract{} = contract,
         decompiled_smart_contracts: decompiled_smart_contracts
       }) do
    decompiled_smart_contract = latest_decompiled_smart_contract(decompiled_smart_contracts)

    %{
      "Address" => to_string(hash),
      "SourceCode" => contract.contract_source_code,
      "ABI" => Jason.encode!(contract.abi),
      "ContractName" => contract.name,
      "DecompiledSourceCode" => decompiled_source_code(decompiled_smart_contract),
      "DecompilerVersion" => decompiler_version(decompiled_smart_contract),
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
