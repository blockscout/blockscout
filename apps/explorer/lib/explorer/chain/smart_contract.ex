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

  alias Ecto.{Changeset, Multi}
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Address,
    ContractMethod,
    Data,
    DecompiledSmartContract,
    Hash,
    InternalTransaction,
    SmartContract,
    SmartContractAdditionalSource,
    Transaction
  }

  alias Explorer.Chain.Address.Name, as: AddressName

  alias Explorer.Chain.SmartContract.{ExternalLibrary, Proxy}
  alias Explorer.Chain.SmartContract.Proxy.EIP1167
  alias Explorer.SmartContract.Helper
  alias Explorer.SmartContract.Solidity.Verifier
  alias Timex.Duration

  @typep api? :: {:api?, true | false}

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

  @type t :: %SmartContract{
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

  @doc """
  Returns smart-contract changeset with checksummed address hash
  """
  @spec address_to_checksum_address(Changeset.t()) :: Changeset.t()
  def address_to_checksum_address(changeset) do
    checksum_address =
      changeset
      |> Changeset.get_field(:address_hash)
      |> to_address_hash()
      |> Address.checksum()

    Changeset.force_change(changeset, :address_hash, checksum_address)
  end

  @doc """
  Returns implementation address and name of the given SmartContract by hash address
  """
  @spec get_implementation_address_hash(any(), any()) :: {any(), any()}
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
        address_hash_to_smart_contract_without_twin(address_hash, options)
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
        Task.async(fn ->
          Proxy.fetch_implementation_address_hash(address_hash, abi, metadata_from_verified_twin, options)
        end)

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

  def save_implementation_data(nil, _, _, _), do: {nil, nil}

  def save_implementation_data(empty_address_hash_string, proxy_address_hash, metadata_from_verified_twin, options)
      when is_burn_signature_extended(empty_address_hash_string) do
    if is_nil(metadata_from_verified_twin) or !metadata_from_verified_twin do
      proxy_address_hash
      |> address_hash_to_smart_contract_without_twin(options)
      |> changeset(%{
        implementation_name: nil,
        implementation_address_hash: nil,
        implementation_fetched_at: DateTime.utc_now()
      })
      |> Repo.update()
    end

    {:empty, :empty}
  end

  def save_implementation_data(implementation_address_hash_string, proxy_address_hash, _, options)
      when is_binary(implementation_address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(implementation_address_hash_string),
         proxy_contract <- address_hash_to_smart_contract_without_twin(proxy_address_hash, options),
         false <- is_nil(proxy_contract),
         %{implementation: %__MODULE__{name: name}, proxy: proxy_contract} <- %{
           implementation: address_hash_to_smart_contract(address_hash, options),
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
        smart_contract = address_hash_to_smart_contract(address_hash, options)

        {implementation_address_hash_string, smart_contract && smart_contract.name}

      _ ->
        {implementation_address_hash_string, nil}
    end
  end

  @doc """
  Returns SmartContract by the given smart-contract address hash, if it is partially verified
  """
  @spec select_partially_verified_by_address_hash(binary() | Hash.t(), keyword) :: boolean() | nil
  def select_partially_verified_by_address_hash(address_hash, options \\ []) do
    query =
      from(
        smart_contract in __MODULE__,
        where: smart_contract.address_hash == ^address_hash,
        select: smart_contract.partially_verified
      )

    Chain.select_repo(options).one(query)
  end

  @doc """
    Extracts creation bytecode (`init`) and transaction (`tx`) or
      internal transaction (`internal_tx`) where the contract was created.
  """
  @spec creation_tx_with_bytecode(binary() | Hash.t()) ::
          %{init: binary(), tx: Transaction.t()} | %{init: binary(), internal_tx: InternalTransaction.t()} | nil
  def creation_tx_with_bytecode(address_hash) do
    creation_tx_query =
      from(
        tx in Transaction,
        where: tx.created_contract_address_hash == ^address_hash,
        where: tx.status == ^1
      )

    tx =
      creation_tx_query
      |> Repo.one()

    if tx do
      with %{input: input} <- tx do
        %{init: Data.to_string(input), tx: tx}
      end
    else
      creation_int_tx_query =
        from(
          itx in InternalTransaction,
          join: t in assoc(itx, :transaction),
          where: itx.created_contract_address_hash == ^address_hash,
          where: t.status == ^1
        )

      internal_tx = creation_int_tx_query |> Repo.one()

      case internal_tx do
        %{init: init} ->
          init_str = Data.to_string(init)
          %{init: init_str, internal_tx: internal_tx}

        _ ->
          nil
      end
    end
  end

  @doc """
  Composes address object for smart-contract
  """
  @spec compose_smart_contract(map(), Hash.t(), any()) :: map()
  def compose_smart_contract(address_result, hash, options) do
    address_verified_twin_contract =
      EIP1167.get_implementation_address(hash, options) ||
        get_address_verified_twin_contract(hash, options).verified_contract

    if address_verified_twin_contract do
      address_verified_twin_contract_updated =
        address_verified_twin_contract
        |> Map.put(:address_hash, hash)
        |> Map.put(:metadata_from_verified_twin, true)
        |> Map.put(:implementation_address_hash, nil)
        |> Map.put(:implementation_name, nil)
        |> Map.put(:implementation_fetched_at, nil)

      address_result
      |> Map.put(:smart_contract, address_verified_twin_contract_updated)
    else
      address_result
    end
  end

  @doc """
  Finds metadata for verification of a contract from verified twins: contracts with the same bytecode
  which were verified previously, returns a single t:SmartContract.t/0
  """
  @spec get_address_verified_twin_contract(Hash.t() | String.t(), any()) :: %{
          :verified_contract => any(),
          :additional_sources => SmartContractAdditionalSource.t() | nil
        }
  def get_address_verified_twin_contract(hash, options \\ [])

  def get_address_verified_twin_contract(hash, options) when is_binary(hash) do
    case Chain.string_to_address_hash(hash) do
      {:ok, address_hash} -> get_address_verified_twin_contract(address_hash, options)
      _ -> %{:verified_contract => nil, :additional_sources => nil}
    end
  end

  def get_address_verified_twin_contract(%Hash{} = address_hash, options) do
    with target_address <- Chain.select_repo(options).get(Address, address_hash),
         false <- is_nil(target_address) do
      verified_contract_twin = get_verified_twin_contract(target_address, options)

      verified_contract_twin_additional_sources =
        SmartContractAdditionalSource.get_contract_additional_sources(verified_contract_twin, options)

      %{
        :verified_contract => check_and_update_constructor_args(verified_contract_twin),
        :additional_sources => verified_contract_twin_additional_sources
      }
    else
      _ ->
        %{:verified_contract => nil, :additional_sources => nil}
    end
  end

  @doc """
  Returns verified smart-contract with the same bytecode of the given smart-contract
  """
  @spec get_verified_twin_contract(Address.t(), any()) :: SmartContract.t() | nil
  def get_verified_twin_contract(%Address{} = target_address, options \\ []) do
    case target_address do
      %{contract_code: %Chain.Data{bytes: contract_code_bytes}} ->
        target_address_hash = target_address.hash

        contract_code_md5 = Helper.contract_code_md5(contract_code_bytes)

        verified_contract_twin_query =
          from(
            smart_contract in __MODULE__,
            where: smart_contract.contract_code_md5 == ^contract_code_md5,
            where: smart_contract.address_hash != ^target_address_hash,
            select: smart_contract,
            limit: 1
          )

        verified_contract_twin_query
        |> Chain.select_repo(options).one(timeout: 10_000)

      _ ->
        nil
    end
  end

  @doc """
  Returns address or smart_contract object with parsed constructor_arguments
  """
  @spec check_and_update_constructor_args(any()) :: any()
  def check_and_update_constructor_args(
        %__MODULE__{address_hash: address_hash, constructor_arguments: nil, verified_via_sourcify: true} =
          smart_contract
      ) do
    if args = Verifier.parse_constructor_arguments_for_sourcify_contract(address_hash, smart_contract.abi) do
      smart_contract |> __MODULE__.changeset(%{constructor_arguments: args}) |> Repo.update()
      %__MODULE__{smart_contract | constructor_arguments: args}
    else
      smart_contract
    end
  end

  def check_and_update_constructor_args(
        %Address{
          hash: address_hash,
          contract_code: deployed_bytecode,
          smart_contract: %__MODULE__{constructor_arguments: nil, verified_via_sourcify: true} = smart_contract
        } = address
      ) do
    if args =
         Verifier.parse_constructor_arguments_for_sourcify_contract(address_hash, smart_contract.abi, deployed_bytecode) do
      smart_contract |> __MODULE__.changeset(%{constructor_arguments: args}) |> Repo.update()
      %Address{address | smart_contract: %__MODULE__{smart_contract | constructor_arguments: args}}
    else
      address
    end
  end

  def check_and_update_constructor_args(other), do: other

  @doc """
  Adds verified metadata from bytecode twin smart-contract to the given smart-contract
  """
  @spec add_twin_info_to_contract(map(), Chain.Hash.t(), Chain.Hash.t() | nil) :: map()
  def add_twin_info_to_contract(address_result, address_verified_twin_contract, _hash)
      when is_nil(address_verified_twin_contract),
      do: address_result

  def add_twin_info_to_contract(address_result, address_verified_twin_contract, hash) do
    address_verified_twin_contract_updated =
      address_verified_twin_contract
      |> Map.put(:address_hash, hash)
      |> Map.put(:metadata_from_verified_twin, true)
      |> Map.put(:implementation_address_hash, nil)
      |> Map.put(:implementation_name, nil)
      |> Map.put(:implementation_fetched_at, nil)

    address_result
    |> Map.put(:smart_contract, address_verified_twin_contract_updated)
  end

  @doc """
  Inserts a `t:SmartContract.t/0`.

  As part of inserting a new smart contract, an additional record is inserted for
  naming the address for reference.
  """
  @spec create_smart_contract(map(), list(), list()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def create_smart_contract(attrs \\ %{}, external_libraries \\ [], secondary_sources \\ []) do
    new_contract = %__MODULE__{}

    attrs =
      attrs
      |> Helper.add_contract_code_md5()

    smart_contract_changeset =
      new_contract
      |> __MODULE__.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)

    new_contract_additional_source = %SmartContractAdditionalSource{}

    smart_contract_additional_sources_changesets =
      if secondary_sources do
        secondary_sources
        |> Enum.map(fn changeset ->
          new_contract_additional_source
          |> SmartContractAdditionalSource.changeset(changeset)
        end)
      else
        []
      end

    address_hash = Changeset.get_field(smart_contract_changeset, :address_hash)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_contract_query =
      Multi.new()
      |> Multi.run(:set_address_verified, fn repo, _ -> set_address_verified(repo, address_hash) end)
      |> Multi.run(:clear_primary_address_names, fn repo, _ ->
        AddressName.clear_primary_address_names(repo, address_hash)
      end)
      |> Multi.insert(:smart_contract, smart_contract_changeset)

    insert_contract_query_with_additional_sources =
      smart_contract_additional_sources_changesets
      |> Enum.with_index()
      |> Enum.reduce(insert_contract_query, fn {changeset, index}, multi ->
        Multi.insert(multi, "smart_contract_additional_source_#{Integer.to_string(index)}", changeset)
      end)

    insert_result =
      insert_contract_query_with_additional_sources
      |> Repo.transaction()

    AddressName.create_primary_address_name(Repo, Changeset.get_field(smart_contract_changeset, :name), address_hash)

    case insert_result do
      {:ok, %{smart_contract: smart_contract}} ->
        {:ok, smart_contract}

      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}

      {:error, :set_address_verified, message, _} ->
        {:error, message}
    end
  end

  @doc """
  Updates a `t:SmartContract.t/0`.

  Has the similar logic as create_smart_contract/1.
  Used in cases when you need to update row in DB contains SmartContract, e.g. in case of changing
  status `partially verified` to `fully verified` (re-verify).
  """
  @spec update_smart_contract(map(), list(), list()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def update_smart_contract(attrs \\ %{}, external_libraries \\ [], secondary_sources \\ []) do
    address_hash = Map.get(attrs, :address_hash)

    query_sources =
      from(
        source in SmartContractAdditionalSource,
        where: source.address_hash == ^address_hash
      )

    _delete_sources = Repo.delete_all(query_sources)

    query = get_smart_contract_query(address_hash)
    smart_contract = Repo.one(query)

    smart_contract_changeset =
      smart_contract
      |> __MODULE__.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)

    new_contract_additional_source = %SmartContractAdditionalSource{}

    smart_contract_additional_sources_changesets =
      if secondary_sources do
        secondary_sources
        |> Enum.map(fn changeset ->
          new_contract_additional_source
          |> SmartContractAdditionalSource.changeset(changeset)
        end)
      else
        []
      end

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_contract_query =
      Multi.new()
      |> Multi.run(:clear_primary_address_names, fn repo, _ ->
        AddressName.clear_primary_address_names(repo, address_hash)
      end)
      |> Multi.update(:smart_contract, smart_contract_changeset)

    insert_contract_query_with_additional_sources =
      smart_contract_additional_sources_changesets
      |> Enum.with_index()
      |> Enum.reduce(insert_contract_query, fn {changeset, index}, multi ->
        Multi.insert(multi, "smart_contract_additional_source_#{Integer.to_string(index)}", changeset)
      end)

    insert_result =
      insert_contract_query_with_additional_sources
      |> Repo.transaction()

    AddressName.create_primary_address_name(Repo, Changeset.get_field(smart_contract_changeset, :name), address_hash)

    case insert_result do
      {:ok, %{smart_contract: smart_contract}} ->
        {:ok, smart_contract}

      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}

      {:error, :set_address_verified, message, _} ->
        {:error, message}
    end
  end

  @doc """
  Converts address hash to smart-contract object
  """
  @spec address_hash_to_smart_contract_without_twin(Hash.Address.t(), [api?]) :: __MODULE__.t() | nil
  def address_hash_to_smart_contract_without_twin(address_hash, options) do
    query = get_smart_contract_query(address_hash)

    Chain.select_repo(options).one(query)
  end

  @doc """
  Converts address hash to smart-contract object with metadata_from_verified_twin=true
  """
  @spec address_hash_to_smart_contract(Hash.Address.t(), [api?]) :: __MODULE__.t() | nil
  def address_hash_to_smart_contract(address_hash, options \\ []) do
    current_smart_contract = address_hash_to_smart_contract_without_twin(address_hash, options)

    with true <- is_nil(current_smart_contract),
         address_verified_twin_contract =
           EIP1167.get_implementation_address(address_hash, options) ||
             get_address_verified_twin_contract(address_hash, options).verified_contract,
         false <- is_nil(address_verified_twin_contract) do
      address_verified_twin_contract
      |> Map.put(:address_hash, address_hash)
      |> Map.put(:metadata_from_verified_twin, true)
      |> Map.put(:implementation_address_hash, nil)
      |> Map.put(:implementation_name, nil)
      |> Map.put(:implementation_fetched_at, nil)
    else
      _ ->
        current_smart_contract
    end
  end

  @doc """
  Checks if it exists a verified `t:Explorer.Chain.SmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash` and `partially_verified` property is not true.

  Returns `true` if found and `false` otherwise.
  """
  @spec verified_with_full_match?(Hash.Address.t() | String.t()) :: boolean()
  def verified_with_full_match?(address_hash, options \\ [])

  def verified_with_full_match?(address_hash_str, options) when is_binary(address_hash_str) do
    case Chain.string_to_address_hash(address_hash_str) do
      {:ok, address_hash} ->
        check_verified_with_full_match(address_hash, options)

      _ ->
        false
    end
  end

  def verified_with_full_match?(address_hash, options) do
    check_verified_with_full_match(address_hash, options)
  end

  @doc """
  Checks if it exists a verified `t:Explorer.Chain.SmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash`.

  Returns `true` if found and `false` otherwise.
  """
  @spec verified?(Hash.Address.t() | String.t()) :: boolean()
  def verified?(address_hash_str) when is_binary(address_hash_str) do
    case Chain.string_to_address_hash(address_hash_str) do
      {:ok, address_hash} ->
        verified_smart_contract_exists?(address_hash)

      _ ->
        false
    end
  end

  def verified?(address_hash) do
    verified_smart_contract_exists?(address_hash)
  end

  @doc """
  Checks if it exists a verified `t:Explorer.Chain.SmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash`.

  Returns `:ok` if found and `:not_found` otherwise.
  """
  @spec check_verified_smart_contract_exists(Hash.Address.t()) :: :ok | :not_found
  def check_verified_smart_contract_exists(address_hash) do
    address_hash
    |> verified_smart_contract_exists?()
    |> Chain.boolean_to_check_result()
  end

  @doc """
  Gets smart-contract ABI from the DB for the given address hash of smart-contract
  """
  @spec get_smart_contract_abi(String.t(), any()) :: any()
  def get_smart_contract_abi(address_hash_string, options \\ [])

  def get_smart_contract_abi(address_hash_string, options)
      when not is_nil(address_hash_string) do
    with {:ok, implementation_address_hash} <- Chain.string_to_address_hash(address_hash_string),
         implementation_smart_contract =
           implementation_address_hash
           |> address_hash_to_smart_contract(options),
         false <- is_nil(implementation_smart_contract) do
      implementation_smart_contract
      |> Map.get(:abi)
    else
      _ ->
        []
    end
  end

  def get_smart_contract_abi(address_hash_string, _) when is_nil(address_hash_string) do
    []
  end

  @doc """
  Gets smart-contract by address hash
  """
  @spec get_smart_contract_query(Hash.Address.t() | binary) :: Ecto.Query.t()
  def get_smart_contract_query(address_hash) do
    from(
      smart_contract in __MODULE__,
      where: smart_contract.address_hash == ^address_hash
    )
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

  defp to_address_hash(string) when is_binary(string) do
    {:ok, address_hash} = Chain.string_to_address_hash(string)
    address_hash
  end

  defp to_address_hash(address_hash), do: address_hash

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

  @spec verified_smart_contract_exists?(Hash.Address.t()) :: boolean()
  defp verified_smart_contract_exists?(address_hash) do
    query = get_smart_contract_query(address_hash)

    Repo.exists?(query)
  end

  defp set_address_verified(repo, address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash
      )

    case repo.update_all(query, set: [verified: true]) do
      {1, _} -> {:ok, []}
      _ -> {:error, "There was an error annotating that the address has been verified."}
    end
  end

  defp check_verified_with_full_match(address_hash, options) do
    smart_contract = address_hash_to_smart_contract_without_twin(address_hash, options)

    if smart_contract, do: !smart_contract.partially_verified, else: false
  end
end
