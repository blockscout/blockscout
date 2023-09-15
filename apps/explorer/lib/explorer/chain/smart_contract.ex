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

  alias Ecto.Changeset
  alias EthereumJSONRPC.Contract
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, ContractMethod, DecompiledSmartContract, Hash}
  alias Explorer.Chain.SmartContract.ExternalLibrary
  alias Explorer.SmartContract.Reader
  alias Timex.Duration

  # supported signatures:
  # 5c60da1b = keccak256(implementation())
  @implementation_signature "5c60da1b"
  # aaf10f42 = keccak256(getImplementation())
  @get_implementation_signature "aaf10f42"

  @burn_address_hash_string "0x0000000000000000000000000000000000000000"
  @burn_address_hash_string_32 "0x0000000000000000000000000000000000000000000000000000000000000000"

  defguard is_burn_signature(term) when term in ["0x", "0x0", @burn_address_hash_string_32]
  defguard is_burn_signature_or_nil(term) when is_burn_signature(term) or term == nil
  defguard is_burn_signature_extended(term) when is_burn_signature(term) or term == @burn_address_hash_string

  @doc """
    Returns burn address hash
  """
  @spec burn_address_hash_string() :: String.t()
  def burn_address_hash_string do
    @burn_address_hash_string
  end

  @typep api? :: {:api?, true | false}

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
  * `file_path` - show the filename or path to the file of the contract source file
  * `is_changed_bytecode` - boolean flag, determines if contract's bytecode was modified
  * `bytecode_checked_at` - timestamp of the last check of contract's bytecode matching (DB and BlockChain)
  * `contract_code_md5` - md5(`t:Explorer.Chain.Address.t/0` `contract_code`)
  * `implementation_name` - name of the proxy implementation
  * `compiler_settings` - raw compilation parameters
  * `implementation_fetched_at` - timestamp of the last fetching contract's implementation info
  * `implementation_address_hash` - address hash of the proxy's implementation if any
  * `autodetect_constructor_args` - field was added for storing user's choice
  * `is_yul` - field was added for storing user's choice
  * `verified_via_eth_bytecode_db` - whether contract automatically verified via eth-bytecode-db or not.
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
          file_path: String.t(),
          is_vyper_contract: boolean | nil,
          is_changed_bytecode: boolean,
          bytecode_checked_at: DateTime.t(),
          contract_code_md5: String.t(),
          implementation_name: String.t() | nil,
          compiler_settings: map() | nil,
          implementation_fetched_at: DateTime.t(),
          implementation_address_hash: Hash.Address.t(),
          autodetect_constructor_args: boolean | nil,
          is_yul: boolean | nil,
          verified_via_eth_bytecode_db: boolean | nil
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
    field(:file_path, :string)
    field(:is_vyper_contract, :boolean)
    field(:is_changed_bytecode, :boolean, default: false)
    field(:bytecode_checked_at, :utc_datetime_usec, default: DateTime.add(DateTime.utc_now(), -86400, :second))
    field(:contract_code_md5, :string)
    field(:implementation_name, :string)
    field(:compiler_settings, :map)
    field(:implementation_fetched_at, :utc_datetime_usec, default: nil)
    field(:implementation_address_hash, Hash.Address, default: nil)
    field(:autodetect_constructor_args, :boolean, virtual: true)
    field(:is_yul, :boolean, virtual: true)
    field(:metadata_from_verified_twin, :boolean, virtual: true)
    field(:verified_via_eth_bytecode_db, :boolean)

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
      :file_path,
      :is_vyper_contract,
      :is_changed_bytecode,
      :bytecode_checked_at,
      :contract_code_md5,
      :implementation_name,
      :compiler_settings,
      :implementation_address_hash,
      :implementation_fetched_at,
      :verified_via_eth_bytecode_db
    ])
    |> validate_required([
      :name,
      :compiler_version,
      :optimization,
      :contract_source_code,
      :address_hash,
      :contract_code_md5
    ])
    |> unique_constraint(:address_hash)
    |> prepare_changes(&upsert_contract_methods/1)
  end

  def invalid_contract_changeset(
        %__MODULE__{} = smart_contract,
        attrs,
        error,
        error_message,
        verification_with_files? \\ false
      ) do
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
        :file_path,
        :is_vyper_contract,
        :is_changed_bytecode,
        :bytecode_checked_at,
        :contract_code_md5,
        :implementation_name,
        :autodetect_constructor_args,
        :verified_via_eth_bytecode_db
      ])
      |> (&if(verification_with_files?,
            do: &1,
            else: validate_required(&1, [:compiler_version, :optimization, :address_hash, :contract_code_md5])
          )).()

    field_to_put_message = if verification_with_files?, do: :files, else: select_error_field(error)

    if error_message do
      add_error(validated, field_to_put_message, error_message(error, error_message))
    else
      add_error(validated, field_to_put_message, error_message(error))
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

  defp upsert_contract_methods(%Changeset{changes: %{abi: abi}} = changeset) do
    ContractMethod.upsert_from_abi(abi, get_field(changeset, :address_hash))

    changeset
  rescue
    exception ->
      message = Exception.format(:error, exception, __STACKTRACE__)

      Logger.error(fn -> ["Error while upserting contract methods: ", message] end)

      changeset
  end

  defp upsert_contract_methods(changeset), do: changeset

  defp error_message(:compilation), do: error_message_with_log("There was an error compiling your contract.")

  defp error_message(:compiler_version),
    do: error_message_with_log("Compiler version does not match, please try again.")

  defp error_message(:generated_bytecode), do: error_message_with_log("Bytecode does not match, please try again.")

  defp error_message(:constructor_arguments),
    do: error_message_with_log("Constructor arguments do not match, please try again.")

  defp error_message(:name), do: error_message_with_log("Wrong contract name, please try again.")
  defp error_message(:json), do: error_message_with_log("Invalid JSON file.")

  defp error_message(:autodetect_constructor_arguments_failed),
    do:
      error_message_with_log(
        "Autodetection of constructor arguments failed. Please try to input constructor arguments manually."
      )

  defp error_message(:no_creation_data),
    do:
      error_message_with_log(
        "The contract creation transaction has not been indexed yet. Please wait a few minutes and try again."
      )

  defp error_message(:unknown_error), do: error_message_with_log("Unable to verify: unknown error.")

  defp error_message(:deployed_bytecode),
    do: error_message_with_log("Deployed bytecode does not correspond to contract creation code.")

  defp error_message(:contract_source_code), do: error_message_with_log("Empty contract source code.")

  defp error_message(string) when is_binary(string), do: error_message_with_log(string)
  defp error_message(%{"message" => string} = error) when is_map(error), do: error_message_with_log(string)

  defp error_message(error) do
    Logger.warn(fn -> ["Unknown verifier error: ", inspect(error)] end)
    "There was an error validating your contract, please try again."
  end

  defp error_message(:compilation, error_message),
    do: error_message_with_log("There was an error compiling your contract: #{error_message}")

  defp error_message_with_log(error_string) do
    Logger.error("Smart-contract verification error: #{error_string}")
    error_string
  end

  defp select_error_field(:no_creation_data), do: :address_hash
  defp select_error_field(:compiler_version), do: :compiler_version

  defp select_error_field(constructor_arguments)
       when constructor_arguments in [:constructor_arguments, :autodetect_constructor_arguments_failed],
       do: :constructor_arguments

  defp select_error_field(:name), do: :name
  defp select_error_field(_), do: :contract_source_code

  def merge_twin_contract_with_changeset(%__MODULE__{} = twin_contract, %Changeset{} = changeset) do
    %__MODULE__{}
    |> changeset(Map.from_struct(twin_contract))
    |> Changeset.put_change(:autodetect_constructor_args, true)
    |> Changeset.put_change(:is_yul, false)
    |> Changeset.force_change(:address_hash, Changeset.get_field(changeset, :address_hash))
  end

  def merge_twin_contract_with_changeset(nil, %Changeset{} = changeset) do
    changeset
    |> Changeset.put_change(:name, "")
    |> Changeset.put_change(:optimization_runs, "200")
    |> Changeset.put_change(:optimization, true)
    |> Changeset.put_change(:evm_version, "default")
    |> Changeset.put_change(:compiler_version, "latest")
    |> Changeset.put_change(:contract_source_code, "")
    |> Changeset.put_change(:autodetect_constructor_args, true)
    |> Changeset.put_change(:is_yul, false)
  end

  def merge_twin_vyper_contract_with_changeset(
        %__MODULE__{is_vyper_contract: true} = twin_contract,
        %Changeset{} = changeset
      ) do
    %__MODULE__{}
    |> changeset(Map.from_struct(twin_contract))
    |> Changeset.force_change(:address_hash, Changeset.get_field(changeset, :address_hash))
  end

  def merge_twin_vyper_contract_with_changeset(%__MODULE__{is_vyper_contract: false}, %Changeset{} = changeset) do
    merge_twin_vyper_contract_with_changeset(nil, changeset)
  end

  def merge_twin_vyper_contract_with_changeset(%__MODULE__{is_vyper_contract: nil}, %Changeset{} = changeset) do
    merge_twin_vyper_contract_with_changeset(nil, changeset)
  end

  def merge_twin_vyper_contract_with_changeset(nil, %Changeset{} = changeset) do
    changeset
    |> Changeset.put_change(:name, "Vyper_contract")
    |> Changeset.put_change(:compiler_version, "latest")
    |> Changeset.put_change(:contract_source_code, "")
  end

  def address_to_checksum_address(changeset) do
    checksum_address =
      changeset
      |> Changeset.get_field(:address_hash)
      |> to_address_hash()
      |> Address.checksum()

    Changeset.force_change(changeset, :address_hash, checksum_address)
  end

  defp to_address_hash(string) when is_binary(string) do
    {:ok, address_hash} = Chain.string_to_address_hash(string)
    address_hash
  end

  defp to_address_hash(address_hash), do: address_hash

  def proxy_contract?(smart_contract, options \\ [])

  def proxy_contract?(%__MODULE__{abi: abi} = smart_contract, options) when not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation" ||
          Chain.master_copy_pattern?(method)
      end)

    if implementation_method_abi ||
         not is_nil(
           smart_contract
           |> get_implementation_address_hash(options)
           |> Tuple.to_list()
           |> List.first()
         ),
       do: true,
       else: false
  end

  def proxy_contract?(_, _), do: false

  def get_implementation_address_hash(smart_contract, options \\ [])

  def get_implementation_address_hash(%__MODULE__{abi: nil}, _), do: {nil, nil}

  def get_implementation_address_hash(%__MODULE__{metadata_from_verified_twin: true} = smart_contract, options) do
    get_implementation_address_hash({:updated, smart_contract}, options)
  end

  def get_implementation_address_hash(
        %__MODULE__{
          address_hash: address_hash,
          implementation_fetched_at: implementation_fetched_at
        } = smart_contract,
        options
      ) do
    updated_smart_contract =
      if Application.get_env(:explorer, :enable_caching_implementation_data_of_proxy) &&
           check_implementation_refetch_necessity(implementation_fetched_at) do
        Chain.address_hash_to_smart_contract_without_twin(address_hash, options)
      else
        smart_contract
      end

    get_implementation_address_hash({:updated, updated_smart_contract})
  end

  def get_implementation_address_hash(
        {:updated,
         %__MODULE__{
           address_hash: address_hash,
           abi: abi,
           implementation_address_hash: implementation_address_hash_from_db,
           implementation_name: implementation_name_from_db,
           implementation_fetched_at: implementation_fetched_at,
           metadata_from_verified_twin: metadata_from_verified_twin
         }},
        options
      ) do
    if check_implementation_refetch_necessity(implementation_fetched_at) do
      get_implementation_address_hash_task =
        Task.async(fn -> get_implementation_address_hash(address_hash, abi, metadata_from_verified_twin, options) end)

      timeout = Application.get_env(:explorer, :implementation_data_fetching_timeout)

      case Task.yield(get_implementation_address_hash_task, timeout) ||
             Task.ignore(get_implementation_address_hash_task) do
        {:ok, {:empty, :empty}} ->
          {nil, nil}

        {:ok, {address_hash, _name} = result} when not is_nil(address_hash) ->
          result

        _ ->
          {db_implementation_data_converter(implementation_address_hash_from_db),
           db_implementation_data_converter(implementation_name_from_db)}
      end
    else
      {db_implementation_data_converter(implementation_address_hash_from_db),
       db_implementation_data_converter(implementation_name_from_db)}
    end
  end

  def get_implementation_address_hash(_, _), do: {nil, nil}

  defp db_implementation_data_converter(nil), do: nil
  defp db_implementation_data_converter(string) when is_binary(string), do: string
  defp db_implementation_data_converter(other), do: to_string(other)

  defp check_implementation_refetch_necessity(nil), do: true

  defp check_implementation_refetch_necessity(timestamp) do
    if Application.get_env(:explorer, :enable_caching_implementation_data_of_proxy) do
      now = DateTime.utc_now()

      average_block_time = get_average_block_time()

      fresh_time_distance =
        case average_block_time do
          0 ->
            Application.get_env(:explorer, :fallback_ttl_cached_implementation_data_of_proxy)

          time ->
            round(time)
        end

      timestamp
      |> DateTime.add(fresh_time_distance, :millisecond)
      |> DateTime.compare(now) != :gt
    else
      true
    end
  end

  defp get_average_block_time do
    if Application.get_env(:explorer, :avg_block_time_as_ttl_cached_implementation_data_of_proxy) do
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} ->
          0

        duration ->
          duration
          |> Duration.to_milliseconds()
      end
    else
      0
    end
  end

  @spec get_implementation_address_hash(Hash.Address.t(), list(), boolean() | nil, [api?]) ::
          {String.t() | nil, String.t() | nil}
  defp get_implementation_address_hash(proxy_address_hash, abi, metadata_from_verified_twin, options)
       when not is_nil(proxy_address_hash) and not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation" && Map.get(method, "stateMutability") == "view"
      end)

    get_implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "getImplementation" && Map.get(method, "stateMutability") == "view"
      end)

    master_copy_method_abi =
      abi
      |> Enum.find(fn method ->
        Chain.master_copy_pattern?(method)
      end)

    implementation_address =
      cond do
        implementation_method_abi ->
          get_implementation_address_hash_basic(@implementation_signature, proxy_address_hash, abi)

        get_implementation_method_abi ->
          get_implementation_address_hash_basic(@get_implementation_signature, proxy_address_hash, abi)

        master_copy_method_abi ->
          get_implementation_address_hash_from_master_copy_pattern(proxy_address_hash)

        true ->
          get_implementation_address_hash_eip_1967(proxy_address_hash)
      end

    save_implementation_data(implementation_address, proxy_address_hash, metadata_from_verified_twin, options)
  end

  defp get_implementation_address_hash(_proxy_address_hash, _abi, _, _) do
    {nil, nil}
  end

  defp get_implementation_address_hash_eip_1967(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    # https://eips.ethereum.org/EIPS/eip-1967
    storage_slot_logic_contract_address = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

    {_status, implementation_address} =
      case Contract.eth_get_storage_at_request(
             proxy_address_hash,
             storage_slot_logic_contract_address,
             nil,
             json_rpc_named_arguments
           ) do
        {:ok, empty_address}
        when is_burn_signature_or_nil(empty_address) ->
          fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments)

        {:ok, implementation_logic_address} ->
          {:ok, implementation_logic_address}

        _ ->
          {:ok, nil}
      end

    abi_decode_address_output(implementation_address)
  end

  # changes requested by https://github.com/blockscout/blockscout/issues/4770
  # for support BeaconProxy pattern
  defp fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    # https://eips.ethereum.org/EIPS/eip-1967
    storage_slot_beacon_contract_address = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

    implementation_method_abi = [
      %{
        "type" => "function",
        "stateMutability" => "view",
        "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
        "name" => "implementation",
        "inputs" => []
      }
    ]

    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot_beacon_contract_address,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address}
      when is_burn_signature_or_nil(empty_address) ->
        fetch_openzeppelin_proxy_implementation(proxy_address_hash, json_rpc_named_arguments)

      {:ok, beacon_contract_address} ->
        case beacon_contract_address
             |> abi_decode_address_output()
             |> get_implementation_address_hash_basic(@implementation_signature, implementation_method_abi) do
          <<implementation_address::binary-size(42)>> ->
            {:ok, implementation_address}

          _ ->
            {:ok, beacon_contract_address}
        end

      _ ->
        {:ok, nil}
    end
  end

  # changes requested by https://github.com/blockscout/blockscout/issues/5292
  defp fetch_openzeppelin_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    # This is the keccak-256 hash of "org.zeppelinos.proxy.implementation"
    storage_slot_logic_contract_address = "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"

    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot_logic_contract_address,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address}
      when is_burn_signature(empty_address) ->
        {:ok, "0x"}

      {:ok, logic_contract_address} ->
        {:ok, logic_contract_address}

      _ ->
        {:ok, nil}
    end
  end

  defp get_implementation_address_hash_basic(signature, proxy_address_hash, abi) do
    implementation_address =
      case Reader.query_contract(
             proxy_address_hash,
             abi,
             %{
               "#{signature}" => []
             },
             false
           ) do
        %{^signature => {:ok, [result]}} -> result
        _ -> nil
      end

    address_to_hex(implementation_address)
  end

  defp get_implementation_address_hash_from_master_copy_pattern(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    master_copy_storage_pointer = "0x0"

    {:ok, implementation_address} =
      case Contract.eth_get_storage_at_request(
             proxy_address_hash,
             master_copy_storage_pointer,
             nil,
             json_rpc_named_arguments
           ) do
        {:ok, empty_address}
        when is_burn_signature(empty_address) ->
          {:ok, "0x"}

        {:ok, logic_contract_address} ->
          {:ok, logic_contract_address}

        _ ->
          {:ok, nil}
      end

    abi_decode_address_output(implementation_address)
  end

  defp save_implementation_data(nil, _, _, _), do: {nil, nil}

  defp save_implementation_data(empty_address_hash_string, proxy_address_hash, metadata_from_verified_twin, options)
       when is_burn_signature_extended(empty_address_hash_string) do
    if is_nil(metadata_from_verified_twin) or !metadata_from_verified_twin do
      proxy_address_hash
      |> Chain.address_hash_to_smart_contract_without_twin(options)
      |> changeset(%{
        implementation_name: nil,
        implementation_address_hash: nil,
        implementation_fetched_at: DateTime.utc_now()
      })
      |> Repo.update()
    end

    {:empty, :empty}
  end

  defp save_implementation_data(implementation_address_hash_string, proxy_address_hash, _, options)
       when is_binary(implementation_address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(implementation_address_hash_string),
         proxy_contract <- Chain.address_hash_to_smart_contract_without_twin(proxy_address_hash, options),
         false <- is_nil(proxy_contract),
         %{implementation: %__MODULE__{name: name}, proxy: proxy_contract} <- %{
           implementation: Chain.address_hash_to_smart_contract(address_hash, options),
           proxy: proxy_contract
         } do
      proxy_contract
      |> changeset(%{
        implementation_name: name,
        implementation_address_hash: implementation_address_hash_string,
        implementation_fetched_at: DateTime.utc_now()
      })
      |> Repo.update()

      {implementation_address_hash_string, name}
    else
      %{implementation: _, proxy: proxy_contract} ->
        proxy_contract
        |> changeset(%{
          implementation_name: nil,
          implementation_address_hash: implementation_address_hash_string,
          implementation_fetched_at: DateTime.utc_now()
        })
        |> Repo.update()

        {implementation_address_hash_string, nil}

      true ->
        {:ok, address_hash} = Chain.string_to_address_hash(implementation_address_hash_string)
        smart_contract = Chain.address_hash_to_smart_contract(address_hash, options)

        {implementation_address_hash_string, smart_contract && smart_contract.name}

      _ ->
        {implementation_address_hash_string, nil}
    end
  end

  defp address_to_hex(address) do
    if address do
      if String.starts_with?(address, "0x") do
        address
      else
        "0x" <> Base.encode16(address, case: :lower)
      end
    end
  end

  defp abi_decode_address_output(nil), do: nil

  defp abi_decode_address_output("0x"), do: burn_address_hash_string()

  defp abi_decode_address_output(address) when is_binary(address) do
    if String.length(address) > 42 do
      "0x" <> String.slice(address, -40, 40)
    else
      address
    end
  end

  defp abi_decode_address_output(_), do: nil
end
