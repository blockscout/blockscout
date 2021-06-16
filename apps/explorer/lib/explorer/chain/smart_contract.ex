defmodule Explorer.Chain.SmartContract do
  @moduledoc """
  The representation of a verified Smart Contract.

  "A contract in the sense of Solidity is a collection of code (its functions)
  and data (its state) that resides at a specific address on the Ethereum
  blockchain."
  http://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, ContractMethod, DecompiledSmartContract, Hash}
  alias Explorer.Chain.SmartContract.ExternalLibrary
  alias Explorer.Repo

  @typedoc """
  The name of a parameter to a function or event.
  """
  @type parameter_name :: String.t()

  @typedoc """
  Canonical Input or output [type](https://solidity.readthedocs.io/en/develop/abi-spec.html#types).

  * `"address"` - equivalent to `uint160`, except for the assumed interpretation and language typing. For computing the
    function selector, `address` is used.
  * `"bool"` - equivalent to uint8 restricted to the values 0 and 1. For computing the function selector, bool is used.
  * `bytes`: dynamic sized byte sequence
  * `"bytes<M>"` - binary type of `M` bytes, `0 < M <= 32`.
  * `"fixed"` - synonym for `"fixed128x18".  For computing the function selection, `"fixed128x8"` has to be used.
  * `"fixed<M>x<N>"` - signed fixed-point decimal number of `M` bits, `8 <= M <= 256`, `M % 8 ==0`, and `0 < N <= 80`,
    which denotes the value `v` as `v / (10 ** N)`.
  * `"function" - an address (`20` bytes) followed by a function selector (`4` bytes). Encoded identical to `bytes24`.
  * `"int"` - synonym for `"int256"`. For computing the function selector `"int256"` has to be used.
  * `"int<M>"` - two’s complement signed integer type of `M` bits, `0 < M <= 256`, `M % 8 == 0`.
  * `"string"` - dynamic sized unicode string assumed to be UTF-8 encoded.
  * `"tuple"` - a tuple.
  * `"(<T1>,<T2>,...,<Tn>)"` - tuple consisting of the `t:type/0`s `<T1>`, …, `Tn`, `n >= 0`.
  * `"<type>[]"` - a variable-length array of elements of the given `type`.
  * `"<type>[M]"` - a fixed-length array of `M` elements, `M >= 0`, of the given `t:type/0`.
  * `"ufixed"` - synonym for `"ufixed128x18".  For computing the function selection, `"ufixed128x8"` has to be used.
  * `"ufixed<M>x<N>"` - unsigned variant of `"fixed<M>x<N>"`
  * `"uint"` - synonym for `"uint256"`. For computing the function selector `"uint256"` has to be used.
  * `"uint<M>"` - unsigned integer type of `M` bits, `0 < M <= 256`, `M % 8 == 0.` e.g. `uint32`, `uint8`, `uint256`.
  """
  @type type :: String.t()

  @typedoc """
  Name of component.
  """
  @type component_name :: String.t()

  @typedoc """
  A component of a [tuple](https://solidity.readthedocs.io/en/develop/abi-spec.html#handling-tuple-types).

  * `"name"` - name of the component.
  * `"type"` - `t:type/0`.
  """
  @type component :: %{String.t() => component_name() | type()}

  @typedoc """
  The components of a [tuple](https://solidity.readthedocs.io/en/develop/abi-spec.html#handling-tuple-types).
  """
  @type components :: [component()]

  @typedoc """
  * `"event"`
  """
  @type event_type :: String.t()

  @typedoc """
  Name of an event in an `t:abi/0`.
  """
  @type event_name :: String.t()

  @typedoc """
  * `true` - if field is part of the `t:Explorer.Chain.Log.t/0` `topics`.
  * `false` - if field is part of the `t:Explorer.Chain.Log.t/0` `data`.
  """
  @type indexed :: boolean()

  @typedoc """
  * `"name"` - `t:parameter_name/0`.
  * `"type"` - `t:type/0`.
  * `"components" `- `t:components/0` used when `"type"` is a tuple type.
  * `"indexed"` - `t:indexed/0`.
  """
  @type event_input :: %{String.t() => parameter_name() | type() | components() | indexed()}

  @typedoc """
  * `true` - event was declared as `anonymous`.
  * `false` - otherwise.
  """
  @type anonymous :: boolean()

  @typedoc """
  * `"type" - `t:event_type/0`
  * `"name"` - `t:event_name/0`
  * `"inputs"` - `t:list/0` of `t:event_input/0`.
  * `"anonymous"` - t:anonymous/0`
  """
  @type event_description :: %{String.t() => term()}

  @typedoc """
  * `"function"`
  * `"constructor"`
  * `"fallback"` - the default, unnamed function
  """
  @type function_type :: String.t()

  @typedoc """
  Name of a function in an `t:abi/0`.
  """
  @type function_name :: String.t()

  @typedoc """
  * `"name"` - t:parameter_name/0`.
  * `"type"` - `t:type/0`.
  * `"components"` - `t:components/0` used when `"type"` is a tuple type.
  """
  @type function_input :: %{String.t() => parameter_name() | type() | components()}

  @typedoc """
  * `"type" - `t:type/0`
  """
  @type function_output :: %{String.t() => type()}

  @typedoc """
  * `"pure"` - [specified to not read blockchain state](https://solidity.readthedocs.io/en/develop/contracts.html#pure-functions).
  * `"view"` - [specified to not modify the blockchain state](https://solidity.readthedocs.io/en/develop/contracts.html#view-functions).
  * `"nonpayable"` - function does not accept Ether.
    **NOTE**: Sending non-zero Ether to non-payable function will revert the transaction.
  * `"payable"` - function accepts Ether.
  """
  @type state_mutability :: String.t()

  @typedoc """
  **Deprecated:** Use `t:function_description/0` `"stateMutability"`:

  * `true` - `"payable"`
  * `false` - `"pure"`, `"view"`, or `"nonpayable"`.
  """
  @type payable :: boolean()

  @typedoc """
  **Deprecated:** Use `t:function_description/0` `"stateMutability"`:

  * `true` - `"pure"` or `"view"`.
  * `false` - `"nonpayable"` or `"payable"`.
  """
  @type constant :: boolean()

  @typedoc """
  The [function description](https://solidity.readthedocs.io/en/develop/abi-spec.html#json) for a function in the
  `t:abi.t/0`.

  * `"type"` - `t:function_type/0`
  * `"name" - `t:function_name/0`
  * `"inputs` - `t:list/0` of `t:function_input/0`.
  * `"outputs" - `t:list/0` of `t:output/0`.
  * `"stateMutability"` - `t:state_mutability/0`
  * `"payable"` - `t:payable/0`.
    **WARNING:** Deprecated and will be removed in the future.  Use `"stateMutability"` instead.
  * `"constant"` - `t:constant/0`.
    **WARNING:** Deprecated and will be removed in the future.  Use `"stateMutability"` instead.
  """
  @type function_description :: %{
          String.t() =>
            function_type()
            | function_name()
            | [function_input()]
            | [function_output()]
            | state_mutability()
            | payable()
            | constant()
        }

  @typedoc """
  The [JSON ABI specification](https://solidity.readthedocs.io/en/develop/abi-spec.html#json) for a contract.
  """
  @type abi :: [event_description | function_description]

  @typedoc """
  * `name` - the human-readable name of the smart contract.
  * `compiler_version` - the version of the Solidity compiler used to compile `contract_source_code` with `optimization`
    into `address` `t:Explorer.Chain.Address.t/0` `contract_code`.
  * `optimization` - whether optimizations were turned on when compiling `contract_source_code` into `address`
    `t:Explorer.Chain.Address.t/0` `contract_code`.
  * `contract_source_code` - the Solidity source code that was compiled by `compiler_version` with `optimization` to
    produce `address` `t:Explorer.Chain.Address.t/0` `contract_code`.
  * `abi` - The [JSON ABI specification](https://solidity.readthedocs.io/en/develop/abi-spec.html#json) for this
    contract.
  * `verified_via_sourcify` - whether contract verified through Sourcify utility or not.
  * `partially_verified` - whether contract verified using partial matched source code or not.
  * `is_vyper_contract` - boolean flag, determines if contract is Vyper or not
  """

  @type t :: %Explorer.Chain.SmartContract{
          name: String.t(),
          compiler_version: String.t(),
          optimization: boolean,
          contract_source_code: String.t(),
          constructor_arguments: String.t() | nil,
          evm_version: String.t() | nil,
          optimization_runs: non_neg_integer() | nil,
          abi: [function_description],
          verified_via_sourcify: boolean | nil,
          partially_verified: boolean | nil,
          is_vyper_contract: boolean | nil
        }

  schema "smart_contracts" do
    field(:name, :string)
    field(:compiler_version, :string)
    field(:optimization, :boolean)
    field(:contract_source_code, :string)
    field(:constructor_arguments, :string)
    field(:evm_version, :string)
    field(:optimization_runs, :integer)
    embeds_many(:external_libraries, ExternalLibrary)
    field(:abi, {:array, :map})
    field(:verified_via_sourcify, :boolean)
    field(:partially_verified, :boolean)
    field(:is_vyper_contract, :boolean)

    has_many(
      :decompiled_smart_contracts,
      DecompiledSmartContract,
      foreign_key: :address_hash
    )

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  def preload_decompiled_smart_contract(contract) do
    Repo.preload(contract, :decompiled_smart_contracts)
  end

  def changeset(%__MODULE__{} = smart_contract, attrs) do
    smart_contract
    |> cast(attrs, [
      :name,
      :compiler_version,
      :optimization,
      :contract_source_code,
      :address_hash,
      :abi,
      :constructor_arguments,
      :evm_version,
      :optimization_runs,
      :verified_via_sourcify,
      :partially_verified,
      :is_vyper_contract
    ])
    |> validate_required([:name, :compiler_version, :optimization, :contract_source_code, :abi, :address_hash])
    |> unique_constraint(:address_hash)
    |> prepare_changes(&upsert_contract_methods/1)
  end

  def invalid_contract_changeset(%__MODULE__{} = smart_contract, attrs, error, error_message) do
    validated =
      smart_contract
      |> cast(attrs, [
        :name,
        :compiler_version,
        :optimization,
        :contract_source_code,
        :address_hash,
        :evm_version,
        :optimization_runs,
        :constructor_arguments,
        :verified_via_sourcify,
        :partially_verified,
        :is_vyper_contract
      ])
      |> validate_required([:name, :compiler_version, :optimization, :address_hash])

    if error_message do
      add_error(validated, :contract_source_code, error_message(error, error_message))
    else
      add_error(validated, :contract_source_code, error_message(error))
    end
  end

  def add_submitted_comment(code, inserted_at) when is_binary(code) do
    code
    |> String.split("\n")
    |> add_submitted_comment(inserted_at)
    |> Enum.join("\n")
  end

  def add_submitted_comment(contract_lines, inserted_at) when is_list(contract_lines) do
    etherscan_index =
      Enum.find_index(contract_lines, fn line ->
        String.contains?(line, "Submitted for verification at Etherscan.io")
      end)

    blockscout_index =
      Enum.find_index(contract_lines, fn line ->
        String.contains?(line, "Submitted for verification at blockscout.com")
      end)

    cond do
      etherscan_index && blockscout_index ->
        List.replace_at(contract_lines, etherscan_index, "*")

      etherscan_index && !blockscout_index ->
        List.replace_at(
          contract_lines,
          etherscan_index,
          "* Submitted for verification at blockscout.com on #{inserted_at}"
        )

      !etherscan_index && !blockscout_index ->
        header = ["/**", "* Submitted for verification at blockscout.com on #{inserted_at}", "*/"]

        header ++ contract_lines

      true ->
        contract_lines
    end
  end

  defp upsert_contract_methods(%Ecto.Changeset{changes: %{abi: abi}} = changeset) do
    ContractMethod.upsert_from_abi(abi, get_field(changeset, :address_hash))

    changeset
  rescue
    exception ->
      message = Exception.format(:error, exception, __STACKTRACE__)

      Logger.error(fn -> ["Error while upserting contract methods: ", message] end)

      changeset
  end

  defp upsert_contract_methods(changeset), do: changeset

  defp error_message(:compilation), do: "There was an error compiling your contract."
  defp error_message(:compiler_version), do: "Compiler version does not match, please try again."
  defp error_message(:generated_bytecode), do: "Bytecode does not match, please try again."
  defp error_message(:constructor_arguments), do: "Constructor arguments do not match, please try again."
  defp error_message(:name), do: "Wrong contract name, please try again."
  defp error_message(_), do: "There was an error validating your contract, please try again."
  defp error_message(:compilation, error_message), do: "There was an error compiling your contract: #{error_message}"
end
