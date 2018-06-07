defmodule Explorer.SmartContract.Solidity.CodeCompiler do
  @moduledoc """
  Module responsible to compile the Solidity code of a given Smart Contract.
  """

  @doc ~S"""
  Compiles a code in the solidity command line.

  Returns a `Map`.

  ## Examples
      iex(1)> Explorer.SmartContract.Solidity.CodeCompiler.run("SimpleStorage", "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }", false)
      %{
        "contracts" => %{
          "SimpleStorage" => %{
            "SimpleStorage" => %{
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
              "evm" => %{
                "bytecode" => %{
                  "linkReferences" => %{},
                  "object" => "608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820017172d01c000255d5c74c0efce764adf7c4ae444d7f7e2ed852f6fb9b73df5d0029",
                  "opcodes" => "PUSH1 0x80 PUSH1 0x40 MSTORE CALLVALUE DUP1 ISZERO PUSH2 0x10 JUMPI PUSH1 0x0 DUP1 REVERT JUMPDEST POP PUSH1 0xDF DUP1 PUSH2 0x1F PUSH1 0x0 CODECOPY PUSH1 0x0 RETURN STOP PUSH1 0x80 PUSH1 0x40 MSTORE PUSH1 0x4 CALLDATASIZE LT PUSH1 0x49 JUMPI PUSH1 0x0 CALLDATALOAD PUSH29 0x100000000000000000000000000000000000000000000000000000000 SWAP1 DIV PUSH4 0xFFFFFFFF AND DUP1 PUSH4 0x60FE47B1 EQ PUSH1 0x4E JUMPI DUP1 PUSH4 0x6D4CE63C EQ PUSH1 0x78 JUMPI JUMPDEST PUSH1 0x0 DUP1 REVERT JUMPDEST CALLVALUE DUP1 ISZERO PUSH1 0x59 JUMPI PUSH1 0x0 DUP1 REVERT JUMPDEST POP PUSH1 0x76 PUSH1 0x4 DUP1 CALLDATASIZE SUB DUP2 ADD SWAP1 DUP1 DUP1 CALLDATALOAD SWAP1 PUSH1 0x20 ADD SWAP1 SWAP3 SWAP2 SWAP1 POP POP POP PUSH1 0xA0 JUMP JUMPDEST STOP JUMPDEST CALLVALUE DUP1 ISZERO PUSH1 0x83 JUMPI PUSH1 0x0 DUP1 REVERT JUMPDEST POP PUSH1 0x8A PUSH1 0xAA JUMP JUMPDEST PUSH1 0x40 MLOAD DUP1 DUP3 DUP2 MSTORE PUSH1 0x20 ADD SWAP2 POP POP PUSH1 0x40 MLOAD DUP1 SWAP2 SUB SWAP1 RETURN JUMPDEST DUP1 PUSH1 0x0 DUP2 SWAP1 SSTORE POP POP JUMP JUMPDEST PUSH1 0x0 DUP1 SLOAD SWAP1 POP SWAP1 JUMP STOP LOG1 PUSH6 0x627A7A723058 KECCAK256 ADD PUSH18 0x72D01C000255D5C74C0EFCE764ADF7C4AE44 0x4d PUSH32 0x7E2ED852F6FB9B73DF5D00290000000000000000000000000000000000000000 ",
                  "sourceMap" => "25:157:0:-;;;;8:9:-1;5:2;;;30:1;27;20:12;5:2;25:157:0;;;;;;;"
                },
                "deployedBytecode" => %{
                  "linkReferences" => %{},
                  "object" => "6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a72305820017172d01c000255d5c74c0efce764adf7c4ae444d7f7e2ed852f6fb9b73df5d0029",
                  "opcodes" => "PUSH1 0x80 PUSH1 0x40 MSTORE PUSH1 0x4 CALLDATASIZE LT PUSH1 0x49 JUMPI PUSH1 0x0 CALLDATALOAD PUSH29 0x100000000000000000000000000000000000000000000000000000000 SWAP1 DIV PUSH4 0xFFFFFFFF AND DUP1 PUSH4 0x60FE47B1 EQ PUSH1 0x4E JUMPI DUP1 PUSH4 0x6D4CE63C EQ PUSH1 0x78 JUMPI JUMPDEST PUSH1 0x0 DUP1 REVERT JUMPDEST CALLVALUE DUP1 ISZERO PUSH1 0x59 JUMPI PUSH1 0x0 DUP1 REVERT JUMPDEST POP PUSH1 0x76 PUSH1 0x4 DUP1 CALLDATASIZE SUB DUP2 ADD SWAP1 DUP1 DUP1 CALLDATALOAD SWAP1 PUSH1 0x20 ADD SWAP1 SWAP3 SWAP2 SWAP1 POP POP POP PUSH1 0xA0 JUMP JUMPDEST STOP JUMPDEST CALLVALUE DUP1 ISZERO PUSH1 0x83 JUMPI PUSH1 0x0 DUP1 REVERT JUMPDEST POP PUSH1 0x8A PUSH1 0xAA JUMP JUMPDEST PUSH1 0x40 MLOAD DUP1 DUP3 DUP2 MSTORE PUSH1 0x20 ADD SWAP2 POP POP PUSH1 0x40 MLOAD DUP1 SWAP2 SUB SWAP1 RETURN JUMPDEST DUP1 PUSH1 0x0 DUP2 SWAP1 SSTORE POP POP JUMP JUMPDEST PUSH1 0x0 DUP1 SLOAD SWAP1 POP SWAP1 JUMP STOP LOG1 PUSH6 0x627A7A723058 KECCAK256 ADD PUSH18 0x72D01C000255D5C74C0EFCE764ADF7C4AE44 0x4d PUSH32 0x7E2ED852F6FB9B73DF5D00290000000000000000000000000000000000000000 ",
                  "sourceMap" => "25:157:0:-;;;;;;;;;;;;;;;;;;;;;;;;;;;;;66:46;;8:9:-1;5:2;;;30:1;27;20:12;5:2;66:46:0;;;;;;;;;;;;;;;;;;;;;;;;;;113:67;;8:9:-1;5:2;;;30:1;27;20:12;5:2;113:67:0;;;;;;;;;;;;;;;;;;;;;;;66:46;108:1;95:10;:14;;;;66:46;:::o;113:67::-;153:4;167:10;;160:17;;113:67;:::o"
                },
                "gasEstimates" => %{
                  "creation" => %{
                    "codeDepositCost" => "44600",
                    "executionCost" => "93",
                    "totalCost" => "44693"
                  },
                  "external" => %{"get()" => "424", "set(uint256)" => "20205"}
                }
              },
              "metadata" => "{\"compiler\":{\"version\":\"0.4.24+commit.e67f0147\"},\"language\":\"Solidity\",\"output\":{\"abi\":[{\"constant\":false,\"inputs\":[{\"name\":\"x\",\"type\":\"uint256\"}],\"name\":\"set\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"get\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}],\"devdoc\":{\"methods\":{}},\"userdoc\":{\"methods\":{}}},\"settings\":{\"compilationTarget\":{\"SimpleStorage\":\"SimpleStorage\"},\"evmVersion\":\"byzantium\",\"libraries\":{},\"optimizer\":{\"enabled\":false,\"runs\":200},\"remappings\":[]},\"sources\":{\"SimpleStorage\":{\"keccak256\":\"0x3f5ecc4c6077dffdfc98d9781295205833bf0558bc2a0c86fc3d5f246808ba34\",\"urls\":[\"bzzr://60d588b13340f26a038f51934f9b8c3cf3928372bc4358848a86960040a3a8e2\"]}},\"version\":1}"
            }
          }
        },
        "sources" => %{"SimpleStorage" => %{"id" => 0}}
      }

  """
  def run(name, code, optimization) do
    {response, _status} =
      System.cmd(
        Application.app_dir(:explorer, "priv/solc.bash"),
        [generate_settings(name, code, optimization)]
      )

    Jason.decode!(response)
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
