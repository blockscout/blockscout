defmodule Explorer.SmartContract.Solidity.CodeCompiler do
  @moduledoc """
  Module responsible to compile the Solidity code of a given Smart Contract.
  """

  @doc ~S"""
  Compiles a code in the solidity command line.

  Returns a `Map`.

  ## Examples
      iex(1)> Explorer.SmartContract.Solidity.CodeCompiler.run("SimpleStorage", "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }", false)
      {:ok, %{
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
        "bytecode" => "608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820017172d01c000255d5c74c0efce764adf7c4ae444d7f7e2ed852f6fb9b73df5d0029",
        "name" => "SimpleStorage"
      }}
  """
  def run(name, code, optimization) do
    {response, _status} =
      System.cmd(
        "node",
        [
          Application.app_dir(:explorer, "priv/compile_solc.js"),
          generate_settings(name, code, optimization),
          "v0.4.24+commit.e67f0147"
        ]
      )

    case Jason.decode!(response) do
      %{
        "contracts" => %{
          ^name => %{
            ^name => %{
              "abi" => abi,
              "evm" => %{
                "bytecode" => %{"object" => bytecode}
              }
            }
          }
        }
      } ->
        {:ok, %{"abi" => abi, "bytecode" => bytecode, "name" => name}}

      _ ->
        {:error, :compilation}
    end
  end

  @doc """
  For more output options check the documentation.
  https://solidity.readthedocs.io/en/v0.4.24/using-the-compiler.html#compiler-input-and-output-json-description
  """
  def generate_settings(name, code, optimization) do
    """
    {
      "language": "Solidity",
      "sources": {
        "#{name}":
        {
          "content": "#{code}"
        }
      },
      "settings": {
        "optimizer": {
          "enabled": #{optimization}
        },
        "outputSelection": {
          "*": {
            "*": [ "evm.bytecode", "evm.deployedBytecode", "evm.gasEstimates", "abi", "metadata" ]
          }
        }
      }
    }
    """
  end
end
