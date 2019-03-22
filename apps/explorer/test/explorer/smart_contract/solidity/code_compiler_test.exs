defmodule Explorer.SmartContract.Solidity.CodeCompilerTest do
  use ExUnit.Case, async: true

  doctest Explorer.SmartContract.Solidity.CodeCompiler

  alias Explorer.Factory
  alias Explorer.SmartContract.Solidity.CodeCompiler

  @compiler_tests "#{File.cwd!()}/test/support/fixture/smart_contract/compiler_tests.json"
                  |> File.read!()
                  |> Jason.decode!()

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
      Enum.each(@compiler_tests, fn compiler_test ->
        compiler_version = compiler_test["compiler_version"]
        external_libraries = compiler_test["external_libraries"]
        name = compiler_test["name"]
        optimize = compiler_test["optimize"]
        contract = compiler_test["contract"]

        {:ok, result} =
          CodeCompiler.run(
            name,
            compiler_version,
            contract,
            optimize,
            "byzantium",
            external_libraries
          )

        clean_result = remove_init_data_and_whisper_data(result["bytecode"])
        expected_result = remove_init_data_and_whisper_data(compiler_test["expected_bytecode"])

        assert clean_result == expected_result
      end)
    end

    test "compiles with constantinople evm version" do
      optimize = false
      name = "MyTest"

      code = """
       pragma solidity 0.5.2;

       contract MyTest {
           constructor() public {
           }

           mapping(address => bytes32) public myMapping;

           function contractHash(address _addr) public {
               bytes32 hash;
               assembly { hash := extcodehash(_addr) }
               myMapping[_addr] = hash;
           }

           function justHash(bytes memory _bytes)
               public
               pure
               returns (bytes32)
           {
               return keccak256(_bytes);
           }
       }
      """

      version = "v0.5.2+commit.1df8f40c"

      evm_version = "constantinople"

      response = CodeCompiler.run(name, version, code, optimize, evm_version)

      assert {:ok,
              %{
                "abi" => _,
                "bytecode" => _,
                "name" => _
              }} = response
    end

    test "compiles in an older solidity version" do
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

  defp remove_init_data_and_whisper_data(code) do
    {res, _} =
      code
      |> String.split("0029")
      |> List.first()
      |> String.split_at(-64)

    res
  end
end
