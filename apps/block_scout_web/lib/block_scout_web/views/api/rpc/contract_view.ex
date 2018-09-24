defmodule BlockScoutWeb.API.RPC.ContractView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("getabi.json", %{abi: abi}) do
    RPCView.render("show.json", data: Jason.encode!(abi))
  end

  def render("getsourcecode.json", %{contract: contract}) do
    RPCView.render("show.json", data: prepare_contract(contract))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_contract(nil) do
    [
      %{
        "SourceCode" => "",
        "ABI" => "Contract source code not verified",
        "ContractName" => "",
        "CompilerVersion" => "",
        "OptimizationUsed" => ""
      }
    ]
  end

  defp prepare_contract(contract) do
    [
      %{
        "SourceCode" => contract.contract_source_code,
        "ABI" => Jason.encode!(contract.abi),
        "ContractName" => contract.name,
        "CompilerVersion" => contract.compiler_version,
        "OptimizationUsed" => if(contract.optimization, do: "1", else: "0")
      }
    ]
  end
end
