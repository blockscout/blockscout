defmodule Explorer.SmartContract.Solidity.CodeCompilerTest do
  use ExUnit.Case, async: true

  doctest Explorer.SmartContract.Solidity.CodeCompiler

  alias Explorer.SmartContract.Solidity.CodeCompiler
  alias Explorer.Factory

  describe "run/2" do
    setup do
      {:ok, contract_code_info: Factory.contract_code_info()}
    end

    test "compiles the latest solidity version", %{contract_code_info: contract_code_info} do
      response =
        CodeCompiler.run(
          contract_code_info.name,
          contract_code_info.version,
          contract_code_info.source_code,
          contract_code_info.optimized
        )

      assert {:ok,
              %{
                "abi" => _,
                "bytecode" => _,
                "name" => _,
                "opcodes" => _
              }} = response
    end

    test "compiles a optimized smart contract", %{contract_code_info: contract_code_info} do
      optimize = true

      response =
        CodeCompiler.run(
          contract_code_info.name,
          contract_code_info.version,
          contract_code_info.source_code,
          optimize
        )

      assert {:ok,
              %{
                "abi" => _,
                "bytecode" => _,
                "name" => _,
                "opcodes" => _
              }} = response
    end

    test "compile in an older solidity version" do
      optimize = false
      name = "SimpleStorage"

      code = """
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

      version = "v0.1.3-nightly.2015.9.25+commit.4457170"

      response = CodeCompiler.run(name, version, code, optimize)

      assert {:ok,
              %{
                "abi" => _,
                "bytecode" => _,
                "name" => _,
                "opcodes" => _
              }} = response
    end

    test "returns a list of errors the compilation isn't possible", %{
      contract_code_info: contract_code_info
    } do
      wrong_code = "pragma solidity ^0.4.24; cont SimpleStorage { "

      response =
        CodeCompiler.run(
          contract_code_info.name,
          contract_code_info.version,
          wrong_code,
          contract_code_info.optimized
        )

      assert {:error, errors} = response
      assert is_list(errors)
    end
  end

  describe "get_contract_info/1" do
    test "return name error when the Contract name doesn't match" do
      name = "Name"
      different_name = "diff_name"

      response = CodeCompiler.get_contract_info(%{name => %{}}, different_name)

      assert {:error, :name} == response
    end

    test "returns an empty list of errors for empty info" do
      name = "Name"

      response = CodeCompiler.get_contract_info(%{}, name)

      assert %{"errors" => []} == response
    end

    test "the contract info is returned when the name matches" do
      contract_inner_info = %{"abi" => %{}, "bytecode" => "", "opcodes" => ""}
      name = "Name"
      contract_info = %{name => contract_inner_info}

      response = CodeCompiler.get_contract_info(contract_info, name)

      assert contract_inner_info == response
    end

    test "the contract info is returned when the name matches with a `:` sufix" do
      name = "Name"
      name_with_sufix = ":Name"
      contract_inner_info = %{"abi" => %{}, "bytecode" => "", "opcodes" => ""}
      contract_info = %{name_with_sufix => contract_inner_info}

      response = CodeCompiler.get_contract_info(contract_info, name)

      assert contract_inner_info == response
    end
  end
end
