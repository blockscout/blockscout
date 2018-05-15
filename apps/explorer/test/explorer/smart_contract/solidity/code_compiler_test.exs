defmodule Explorer.SmartContract.Solidity.CodeCompilerTest do
  use ExUnit.Case, async: true

  doctest Explorer.SmartContract.Solidity.CodeCompiler

  alias Explorer.SmartContract.Solidity.CodeCompiler

  describe "run" do
    test "compiles a smart contract using the solidity command line" do
      name = "SimpleStorage"

      code = """
      pragma solidity ^0.4.23;

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

      response = CodeCompiler.run(name, code)

      assert response["contracts"] != nil
    end
  end

  describe "generate_settings" do
    test "creates a json file with the solidity compiler expected settings" do
      name = "SimpleStorage"

      code = """
      pragma solidity ^0.4.23;

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

      generated = CodeCompiler.generate_settings(name, code)

      assert String.contains?(generated, "contract SimpleStorage") == true
      assert String.contains?(generated, "settings") == true
    end
  end
end
