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
          name: contract_code_info.name,
          compiler_version: contract_code_info.version,
          code: contract_code_info.source_code,
          optimize: contract_code_info.optimized,
          evm_version: "byzantium"
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
          name: contract_code_info.name,
          compiler_version: contract_code_info.version,
          code: contract_code_info.source_code,
          optimize: optimize,
          evm_version: "byzantium"
        )

      assert {:ok,
              %{
                "abi" => _,
                "bytecode" => _,
                "name" => _
              }} = response
    end

    test "compiles smart contract with default evm version", %{contract_code_info: contract_code_info} do
      optimize = true

      response =
        CodeCompiler.run(
          name: contract_code_info.name,
          compiler_version: contract_code_info.version,
          code: contract_code_info.source_code,
          optimize: optimize,
          evm_version: "default"
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
            name: name,
            compiler_version: compiler_version,
            code: contract,
            optimize: optimize,
            evm_version: "byzantium",
            external_libs: external_libraries
          )

        clean_result = remove_init_data_and_whisper_data(result["bytecode"])
        expected_result = remove_init_data_and_whisper_data(compiler_test["tx_input"])

        assert expected_result == clean_result
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

      response =
        CodeCompiler.run(
          name: name,
          compiler_version: version,
          code: code,
          optimize: optimize,
          evm_version: evm_version
        )

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

      version = "v0.1.3+commit.028f561d"

      response = CodeCompiler.run(name: name, compiler_version: version, code: code, optimize: optimize)

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
          name: contract_code_info.name,
          compiler_version: contract_code_info.version,
          code: wrong_code,
          optimize: contract_code_info.optimized
        )

      assert {:error, :compilation} = response
    end

    test "returns constructor in abi" do
      code = """
        pragma solidity ^0.4.22;

        contract OwnedToken {
            // TokenCreator is a contract type that is defined below.
            // It is fine to reference it as long as it is not used
            // to create a new contract.
            TokenCreator creator;
            address owner;
            bytes32 name;

            // This is the constructor which registers the
            // creator and the assigned name.
            constructor(bytes32 _name) public {
                // State variables are accessed via their name
                // and not via e.g. this.owner. This also applies
                // to functions and especially in the constructors,
                // you can only call them like that ("internally"),
                // because the contract itself does not exist yet.
                owner = msg.sender;
                // We do an explicit type conversion from `address`
                // to `TokenCreator` and assume that the type of
                // the calling contract is TokenCreator, there is
                // no real way to check that.
                creator = TokenCreator(msg.sender);
                name = _name;
            }

            function changeName(bytes32 newName) public {
                // Only the creator can alter the name --
                // the comparison is possible since contracts
                // are implicitly convertible to addresses.
                if (msg.sender == address(creator))
                    name = newName;
            }

            function transfer(address newOwner) public {
                // Only the current owner can transfer the token.
                if (msg.sender != owner) return;
                // We also want to ask the creator if the transfer
                // is fine. Note that this calls a function of the
                // contract defined below. If the call fails (e.g.
                // due to out-of-gas), the execution here stops
                // immediately.
                if (creator.isTokenTransferOK(owner, newOwner))
                    owner = newOwner;
            }
        }

        contract TokenCreator {
            function createToken(bytes32 name)
               public
               returns (OwnedToken tokenAddress)
            {
                // Create a new Token contract and return its address.
                // From the JavaScript side, the return type is simply
                // `address`, as this is the closest type available in
                // the ABI.
                return new OwnedToken(name);
            }

            function changeName(OwnedToken tokenAddress, bytes32 name)  public {
                // Again, the external type of `tokenAddress` is
                // simply `address`.
                tokenAddress.changeName(name);
            }

            function isTokenTransferOK(address currentOwner, address newOwner)
                public
                view
                returns (bool ok)
            {
                // Check some arbitrary condition.
                address tokenAddress = msg.sender;
                return (keccak256(newOwner) & 0xff) == (bytes20(tokenAddress) & 0xff);
            }
        }
      """

      name = "OwnedToken"
      compiler_version = "v0.4.22+commit.4cb486ee"

      {:ok, %{"abi" => abi}} =
        CodeCompiler.run(
          name: name,
          compiler_version: compiler_version,
          code: code,
          evm_version: "byzantium",
          optimize: true
        )

      assert Enum.any?(abi, fn el -> el["type"] == "constructor" end)
    end

    test "can compile a large file" do
      path = File.cwd!() <> "/test/support/fixture/smart_contract/large_smart_contract.sol"
      contract = File.read!(path)

      assert {:ok, %{"abi" => abi}} =
               CodeCompiler.run(
                 name: "HomeWorkDeployer",
                 compiler_version: "v0.5.9+commit.e560f70d",
                 code: contract,
                 evm_version: "constantinople",
                 optimize: true
               )
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

  # describe "allowed_evm_versions/0" do
  #   test "returns allowed evm versions defined by ALLOWED_EVM_VERSIONS env var" do
  #     Application.put_env(:explorer, :allowed_evm_versions, "CustomEVM1,CustomEVM2,CustomEVM3")
  #     response = CodeCompiler.allowed_evm_versions()

  #     assert ["CustomEVM1", "CustomEVM2", "CustomEVM3"] = response
  #   end

  #   test "returns allowed evm versions defined by not trimmed ALLOWED_EVM_VERSIONS env var" do
  #     Application.put_env(:explorer, :allowed_evm_versions, "CustomEVM1,  CustomEVM2, CustomEVM3")
  #     response = CodeCompiler.allowed_evm_versions()

  #     assert ["CustomEVM1", "CustomEVM2", "CustomEVM3"] = response
  #   end

  #   test "returns default_allowed_evm_versions" do
  #     Application.put_env(
  #       :explorer,
  #       :allowed_evm_versions,
  #       "homestead,tangerineWhistle,spuriousDragon,byzantium,constantinople,petersburg"
  #     )

  #     response = CodeCompiler.allowed_evm_versions()

  #     assert ["homestead", "tangerineWhistle", "spuriousDragon", "byzantium", "constantinople", "petersburg"] = response
  #   end
  # end

  defp remove_init_data_and_whisper_data(code) do
    {res, _} =
      code
      |> String.split("0029")
      |> List.first()
      |> String.split_at(-64)

    res
  end
end
