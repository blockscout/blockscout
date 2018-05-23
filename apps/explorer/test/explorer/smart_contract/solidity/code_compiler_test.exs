defmodule Explorer.SmartContract.Solidity.CodeCompilerTest do
  use ExUnit.Case, async: true

  doctest Explorer.SmartContract.Solidity.CodeCompiler

  alias Explorer.SmartContract.Solidity.CodeCompiler

  describe "run/2" do
    test "compiles a smart contract using the solidity command line" do
      name = "SimpleStorage"
      optimization = false

      code = """
      pragma solidity ^0.4.24;

      contract SimpleStorage {
          uint storedData;

          function set(uint x) public {
              storedData = x;
          }

          function get() public constant returns (uint) {
              return storedData;
          }
      }
      """

      response = CodeCompiler.run(name, code, optimization)

      assert %{
               "contracts" => %{
                 ^name => %{
                   ^name => %{
                     "abi" => _,
                     "evm" => %{
                       "bytecode" => %{"object" => _}
                     }
                   }
                 }
               }
             } = response
    end
  end

  describe "generate_settings/2" do
    test "creates a json file with the solidity compiler expected settings" do
      name = "SimpleStorage"
      optimization = false

      code = """
      pragma solidity ^0.4.24;

      contract SimpleStorage {
          uint storedData;

          function set(uint x) public {
              storedData = x;
          }

          function get() public constant returns (uint) {
              return storedData;
          }
      }
      """

      generated = CodeCompiler.generate_settings(name, code, optimization)

      assert String.contains?(generated, "contract SimpleStorage") == true
      assert String.contains?(generated, "settings") == true
    end
  end
end
