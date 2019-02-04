defmodule Explorer.SmartContract.Solidity.CodeCompiler do
  @moduledoc """
  Module responsible to compile the Solidity code of a given Smart Contract.
  """

  @new_contract_name "New.sol"

  @doc """
  Compiles a code in the solidity command line.

  Returns a `Map`.

  ## Examples

      iex(1)> Explorer.SmartContract.Solidity.CodeCompiler.run(
      ...>      "SimpleStorage",
      ...>      "v0.4.24+commit.e67f0147",
      ...>      \"""
      ...>      pragma solidity ^0.4.24;
      ...>
      ...>      contract SimpleStorage {
      ...>          uint storedData;
      ...>
      ...>          function set(uint x) public {
      ...>              storedData = x;
      ...>          }
      ...>
      ...>          function get() public constant returns (uint) {
      ...>              return storedData;
      ...>          }
      ...>      }
      ...>      \""",
      ...>      false
      ...>  )
      {
        :ok,
        %{
          "abi" => [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            },
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ],
          "bytecode" => "6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820834bdab406d80509618957aa1a5ad1a4b77f4f1149078675940494ebe5b4147b0029",
          "name" => "SimpleStorage"
        }
      }
  """
  def run(name, compiler_version, code, optimize, external_libs \\ %{}) do
    {response, _status} =
      System.cmd(
        "node",
        [
          Application.app_dir(:explorer, "priv/compile_solc.js"),
          code,
          compiler_version,
          optimize_value(optimize),
          @new_contract_name
        ]
      )

    with {:ok, contracts} <- Jason.decode(response),
         %{"abi" => abi, "evm" => %{"deployedBytecode" => %{"object" => bytecode}}} <- get_contract_info(contracts, name) do
      bytecode_with_libraries = add_library_addresses(bytecode, external_libs)

      {:ok, %{"abi" => abi, "bytecode" => bytecode_with_libraries, "name" => name}}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :compilation}

      error ->
        parse_error(error)
    end
  end

  def get_contract_info(contracts, _) when contracts == %{}, do: {:error, :compilation}

  def get_contract_info(contracts, name) do
    new_versions_name = ":" <> name

    case contracts do
      %{^new_versions_name => response} ->
        response

      %{^name => response} ->
        response

      _ ->
        {:error, :name}
    end
  end

  defp add_library_addresses(bytecode, external_libs) do
    Enum.reduce(external_libs, bytecode, fn {library_name, address}, acc ->
      placeholder = String.replace(@new_contract_name, ".", "\.") <> ":" <> library_name
      regex = Regex.compile!("_+#{placeholder}_+")
      address = String.replace(address, "0x", "")

      String.replace(acc, regex, address)
    end)
  end

  def parse_error(%{"error" => error}), do: {:error, [error]}
  def parse_error(%{"errors" => errors}), do: {:error, errors}
  def parse_error({:error, _} = error), do: error

  defp optimize_value(false), do: "0"
  defp optimize_value("false"), do: "0"

  defp optimize_value(true), do: "1"
  defp optimize_value("true"), do: "1"
end
