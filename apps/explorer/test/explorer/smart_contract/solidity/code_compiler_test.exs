defmodule Explorer.SmartContract.Solidity.CodeCompilerTest do
  use ExUnit.Case, async: true

  doctest Explorer.SmartContract.Solidity.CodeCompiler

  alias Explorer.SmartContract.Solidity.CodeCompiler
  alias Explorer.Factory

  @compiler_tests Jason.decode!(File.read!(System.cwd!() <> "/test/support/fixture/smart_contract/compiler_tests.json"))

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
                "name" => _
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
                "name" => _
              }} = response
    end

    test "compiles code with external libraries" do
      {:ok, result} =
        CodeCompiler.run(
          "MintedTokenCappedCrowdsaleExt",
          "v0.4.11+commit.68ef5810",
          @compiler_tests["contract"],
          true,
          %{"SafeMathLibExt" => "0x54ca5a7c536dbed5897b78d30a93dcd0e46fbdac"}
        )

      assert result["bytecode"] == @compiler_tests["expected_bytecode"]
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
                "name" => _
              }} = response
    end

    test "returns compilation error when compilation isn't possible", %{
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

      assert {:error, :compilation} = response
    end
  end

  describe "get_contract_info/1" do
    test "return name error when the Contract name doesn't match" do
      name = "Name"
      different_name = "diff_name"

      response = CodeCompiler.get_contract_info(%{name => %{}}, different_name)

      assert {:error, :name} == response
    end

    test "returns compilation error for empty info" do
      name = "Name"

      response = CodeCompiler.get_contract_info(%{}, name)

      assert {:error, :compilation} == response
    end

    test "the contract info is returned when the name matches" do
      contract_inner_info = %{"abi" => %{}, "bytecode" => ""}
      name = "Name"
      contract_info = %{name => contract_inner_info}

      response = CodeCompiler.get_contract_info(contract_info, name)

      assert contract_inner_info == response
    end

    test "the contract info is returned when the name matches with a `:` suffix" do
      name = "Name"
      name_with_suffix = ":Name"
      contract_inner_info = %{"abi" => %{}, "bytecode" => ""}
      contract_info = %{name_with_suffix => contract_inner_info}

      response = CodeCompiler.get_contract_info(contract_info, name)

      assert contract_inner_info == response
    end
  end
end
