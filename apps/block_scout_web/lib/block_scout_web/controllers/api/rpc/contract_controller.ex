defmodule BlockScoutWeb.API.RPC.ContractController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.RPC.{AddressController, Helper}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.SmartContract.Proxy.VerificationStatus, as: ProxyVerificationStatus
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.Etherscan.Contracts
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Explorer.SmartContract.Solidity.{Publisher, PublishHelper}
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher
  alias Explorer.ThirdPartyIntegrations.Sourcify

  if @chain_type == :zksync do
    @optimization_runs "0"
  else
    @optimization_runs 200
  end

  @smth_went_wrong "Something went wrong while publishing the contract"
  @verified "Smart-contract already verified."
  @invalid_address "Invalid address hash"
  @invalid_args "Invalid args format"
  @address_required "Query parameter address is required"
  @addresses_required "Query parameter contractaddresses is required"
  @contract_not_found "Smart-contract not found or is not verified"
  @restricted_access "Access to this address is restricted"
  @not_a_smart_contract "The address is not a smart contract"

  @addresses_limit 10
  @api_true [api?: true]

  @doc """
    Function to handle getcontractcreation request
  """
  @spec getcontractcreation(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def getcontractcreation(conn, %{"contractaddresses" => contract_address_hash_strings} = params) do
    addresses =
      contract_address_hash_strings
      |> String.split(",")
      |> Enum.take(@addresses_limit)
      |> Enum.map(fn address_hash_string ->
        case validate_address(address_hash_string, params) do
          {:ok, _address_hash, address} ->
            contract_creation_internal_transaction_with_transaction_association = [
              contract_creation_internal_transaction: {
                Address.contract_creation_internal_transaction_preload_query(),
                :transaction
              }
            ]

            Address.maybe_preload_smart_contract_associations(
              address,
              [
                Address.contract_creation_transaction_association(),
                contract_creation_internal_transaction_with_transaction_association
              ],
              @api_true
            )

          _ ->
            nil
        end
      end)

    render(conn, :getcontractcreation, %{addresses: addresses})
  end

  def getcontractcreation(conn, _params) do
    render(conn, :error, error: @addresses_required, data: @addresses_required)
  end

  def verify(conn, %{"addressHash" => address_hash} = params) do
    with {:params, {:ok, fetched_params}} <- {:params, fetch_verify_params(params)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:params, external_libraries} <-
           {:params, fetch_external_libraries(params)},
         {:not_a_smart_contract, bytecode} when bytecode != "0x" <-
           {:not_a_smart_contract, Chain.smart_contract_bytecode(casted_address_hash, @api_true)},
         {:publish, {:ok, _}} <-
           {:publish, Publisher.publish(address_hash, fetched_params, external_libraries)} do
      address = Contracts.address_hash_to_address_with_source_code(casted_address_hash)

      render(conn, :verify, %{contract: address})
    else
      {:publish,
       {:error,
        %Ecto.Changeset{
          errors: [
            address_hash:
              {"has already been taken",
               [
                 constraint: :unique,
                 constraint_name: "smart_contracts_address_hash_index"
               ]}
          ]
        }}} ->
        render(conn, :error, error: @verified)

      {:publish, {:error, error}} ->
        Logger.error(fn ->
          [
            @smth_went_wrong,
            ": ",
            inspect(error)
          ]
        end)

        render(conn, :error, error: "#{@smth_went_wrong}: #{inspect(error.errors)}")

      {:format, :error} ->
        render(conn, :error, error: @invalid_address)

      {:params, {:error, error}} ->
        render(conn, :error, error: error)

      {:not_a_smart_contract, _} ->
        render(conn, :error, error: @not_a_smart_contract, data: @not_a_smart_contract)
    end
  end

  def verify_via_sourcify(conn, %{"addressHash" => address_hash} = input) do
    files =
      if Map.has_key?(input, "files") do
        input["files"]
      else
        []
      end

    if SmartContract.verified_with_full_match?(address_hash) do
      render(conn, :error, error: @verified)
    else
      case Sourcify.check_by_address(address_hash) do
        {:ok, _verified_status} ->
          get_metadata_and_publish(address_hash, conn)

        _ ->
          with {:ok, files_array} <- prepare_params(files),
               {:ok, validated_files} <- validate_files(files_array) do
            verify_and_publish(address_hash, validated_files, conn)
          else
            {:error, error} ->
              render(conn, :error, error: error)
          end
      end
    end
  end

  def verifysourcecode(
        conn,
        %{
          "codeformat" => "solidity-standard-json-input",
          "contractaddress" => address_hash,
          "sourceCode" => json_input
        } = params
      ) do
    with {:check_verified_status, false} <-
           {:check_verified_status, SmartContract.verified_with_full_match?(address_hash)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:params, {:ok, fetched_params}} <- {:params, fetch_verifysourcecode_params(params)},
         {:not_a_smart_contract, bytecode} when bytecode != "0x" <-
           {:not_a_smart_contract, Chain.smart_contract_bytecode(casted_address_hash, @api_true)},
         uid <- VerificationStatus.generate_uid(address_hash) do
      Que.add(SolidityPublisherWorker, {"json_api", fetched_params, json_input, uid})

      render(conn, :show, %{result: uid})
    else
      {:check_verified_status, true} ->
        render(conn, :error, error: @verified, data: @verified)

      {:format, :error} ->
        render(conn, :error, error: @invalid_address, data: @invalid_address)

      {:params, {:error, error}} ->
        render(conn, :error, error: error, data: error)

      {:not_a_smart_contract, _} ->
        render(conn, :error, error: @not_a_smart_contract, data: @not_a_smart_contract)
    end
  end

  def verifysourcecode(conn, %{"codeformat" => "solidity-standard-json-input"}) do
    render(conn, :error, error: "Missing sourceCode or contractaddress fields")
  end

  def verifysourcecode(
        conn,
        %{
          "codeformat" => "solidity-single-file",
          "contractaddress" => address_hash
        } = params
      ) do
    with {:check_verified_status, false} <-
           {:check_verified_status, SmartContract.verified_with_full_match?(address_hash)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:params, {:ok, fetched_params}} <- {:params, fetch_verifysourcecode_solidity_single_file_params(params)},
         {:not_a_smart_contract, bytecode} when bytecode != "0x" <-
           {:not_a_smart_contract, Chain.smart_contract_bytecode(casted_address_hash, @api_true)},
         external_libraries <- fetch_external_libraries_for_verifysourcecode(params),
         uid <- VerificationStatus.generate_uid(address_hash) do
      Que.add(SolidityPublisherWorker, {"flattened_api", fetched_params, external_libraries, uid})

      render(conn, :show, %{result: uid})
    else
      {:check_verified_status, true} ->
        render(conn, :error, error: @verified, data: @verified)

      {:format, :error} ->
        render(conn, :error, error: @invalid_address, data: @invalid_address)

      {:params, {:error, error}} ->
        render(conn, :error, error: error, data: error)

      {:not_a_smart_contract, _} ->
        render(conn, :error, error: @not_a_smart_contract, data: @not_a_smart_contract)
    end
  end

  def verifysourcecode(conn, _params) do
    render(conn, :error, error: "Missing codeformat field")
  end

  def checkverifystatus(conn, %{"guid" => guid}) do
    case VerificationStatus.fetch_status(guid) do
      :pending ->
        render(conn, :show, %{result: "Pending in queue"})

      :pass ->
        render(conn, :show, %{result: "Pass - Verified"})

      :fail ->
        render(conn, :show, %{result: "Fail - Unable to verify"})

      :unknown_uid ->
        render(conn, :show, %{result: "Unknown UID"})
    end
  end

  def verifyproxycontract(conn, %{"address" => address_hash_string} = params) do
    with {:ok, address_hash, %Address{smart_contract: smart_contract}} <-
           validate_address(address_hash_string, params,
             necessity_by_association: %{:smart_contract => :optional},
             api?: true
           ),
         {:not_found, false} <- {:not_found, is_nil(smart_contract)},
         implementation_updated_at <- Implementation.get_proxy_implementation_updated_at(address_hash, []),
         {:time_interval, true} <-
           {:time_interval, Implementation.check_implementation_refetch_necessity(implementation_updated_at)},
         uid <- ProxyVerificationStatus.generate_uid(address_hash) do
      ProxyVerificationStatus.insert_status(uid, :pending, address_hash)

      Implementation.get_implementation(smart_contract,
        timeout: 0,
        uid: uid,
        callback: &ProxyVerificationStatus.set_proxy_verification_result/2
      )

      render(conn, :show, %{result: uid})
    else
      {:format, :error} ->
        render(conn, :error, error: @invalid_address)

      {:not_found, _} ->
        render(conn, :error, error: @contract_not_found)

      {:restricted_access, true} ->
        render(conn, :error, error: @restricted_access)

      {:time_interval, false} ->
        render(conn, :error, error: "Only one attempt in #{Implementation.get_fresh_time_distance()}ms")
    end
  end

  def checkproxyverification(conn, %{"guid" => guid}) do
    submission = ProxyVerificationStatus.fetch_status(guid)

    case submission && submission.status do
      :pending ->
        render(conn, :show, %{result: "Verification in progress"})

      :pass ->
        implementation_address_hashes =
          Implementation.get_proxy_implementations(submission.contract_address_hash, []).address_hashes

        result =
          if Enum.count(implementation_address_hashes) == 1 do
            implementation_address_hash = Enum.at(implementation_address_hashes, 0)

            "The proxy's (#{submission.contract_address_hash}) implementation contract is found at #{implementation_address_hash} and is successfully updated."
          else
            "The proxy's (#{submission.contract_address_hash}) implementation contracts are found at #{inspect(implementation_address_hashes)} and they've been successfully updated."
          end

        render(conn, :show, %{
          result: result
        })

      :fail ->
        render(conn, :error, %{
          error: "NOTOK",
          data: "A corresponding implementation contract was unfortunately not detected for the proxy address."
        })

      _ ->
        render(conn, :show, %{result: "Unknown UID"})
    end
  end

  defp prepare_params(files) when is_struct(files) do
    {:error, @invalid_args}
  end

  defp prepare_params(files) when is_map(files) do
    {:ok, PublishHelper.prepare_files_array(files)}
  end

  defp prepare_params(files) when is_list(files) do
    {:ok, files}
  end

  defp prepare_params(_arg) do
    {:error, @invalid_args}
  end

  defp validate_files(files) do
    if length(files) < 2 do
      {:error, "You should attach at least 2 files"}
    else
      files_array =
        files
        |> Enum.filter(fn file -> validate_filename(file.filename) end)

      jsons =
        files_array
        |> Enum.filter(fn file -> SmartContractHelper.json_file?(file.filename) end)

      sols =
        files_array
        |> Enum.filter(fn file -> SmartContractHelper.sol_file?(file.filename) end)

      if length(jsons) > 0 and length(sols) > 0 do
        {:ok, files_array}
      else
        {:error, "You should attach at least one *.json and one *.sol files"}
      end
    end
  end

  defp validate_filename(filename) do
    case List.last(String.split(String.downcase(filename), ".")) do
      "sol" ->
        true

      "json" ->
        true

      _ ->
        false
    end
  end

  defp get_metadata_and_publish(address_hash_string, conn) do
    case Sourcify.get_metadata(address_hash_string) do
      {:ok, verification_metadata} ->
        case Sourcify.parse_params_from_sourcify(address_hash_string, verification_metadata) do
          %{"params_to_publish" => params_to_publish, "abi" => abi, "secondary_sources" => secondary_sources} ->
            publish_and_handle_response_without_broadcast(
              address_hash_string,
              params_to_publish,
              abi,
              secondary_sources,
              conn
            )

          {:error, :metadata} ->
            render(conn, :error, error: Sourcify.no_metadata_message())

          _ ->
            render(conn, :error, error: Sourcify.failed_verification_message())
        end

      {:error, %{"error" => error}} ->
        render(conn, :error, error: error)
    end
  end

  defp publish_and_handle_response_without_broadcast(
         address_hash_string,
         params_to_publish,
         abi,
         secondary_sources,
         conn
       ) do
    case PublishHelper.publish_without_broadcast(%{
           "addressHash" => address_hash_string,
           "params" => params_to_publish,
           "abi" => abi,
           "secondarySources" => secondary_sources
         }) do
      {:ok, _contract} ->
        {:format, {:ok, address_hash}} = to_address_hash(address_hash_string)
        address = Contracts.address_hash_to_address_with_source_code(address_hash)
        render(conn, :verify, %{contract: address})

      {:error, changeset} ->
        render(conn, :error, error: changeset)
    end
  end

  defp verify_and_publish(address_hash_string, files_array, conn) do
    case Sourcify.verify(address_hash_string, files_array, nil) do
      {:ok, _verified_status} ->
        case Sourcify.check_by_address(address_hash_string) do
          {:ok, _verified_status} ->
            get_metadata_and_publish(address_hash_string, conn)

          {:error, %{"error" => error}} ->
            render(conn, :error, error: error)

          {:error, error} ->
            render(conn, :error, error: error)
        end

      {:error, %{"error" => error}} ->
        render(conn, :error, error: error)

      {:error, error} ->
        render(conn, :error, error: error)
    end
  end

  def verify_vyper_contract(conn, %{"addressHash" => address_hash} = params) do
    with {:params, {:ok, fetched_params}} <- {:params, fetch_vyper_verify_params(params)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:not_a_smart_contract, bytecode} when bytecode != "0x" <-
           {:not_a_smart_contract, Chain.smart_contract_bytecode(casted_address_hash, @api_true)},
         {:publish, {:ok, _}} <-
           {:publish, VyperPublisher.publish(address_hash, fetched_params)} do
      address = Contracts.address_hash_to_address_with_source_code(casted_address_hash)

      render(conn, :verify, %{contract: address})
    else
      {:publish,
       {:error,
        %Ecto.Changeset{
          errors: [
            address_hash:
              {"has already been taken",
               [
                 constraint: :unique,
                 constraint_name: "smart_contracts_address_hash_index"
               ]}
          ]
        }}} ->
        render(conn, :error, error: @verified)

      {:publish, _} ->
        render(conn, :error, error: @smth_went_wrong)

      {:format, :error} ->
        render(conn, :error, error: @invalid_address)

      {:params, {:error, error}} ->
        render(conn, :error, error: error)

      {:not_a_smart_contract, _} ->
        render(conn, :error, error: @not_a_smart_contract, data: @not_a_smart_contract)
    end
  end

  def listcontracts(conn, params) do
    with pagination_options <- Helper.put_pagination_options(%{}, params),
         {:params, {:ok, options}} <- {:params, add_filters(pagination_options, params)} do
      options_with_defaults =
        options
        |> Map.put_new(:page_number, 0)
        |> Map.put_new(:page_size, 10)

      contracts = list_contracts(options_with_defaults)

      conn
      |> put_status(200)
      |> render(:listcontracts, %{contracts: contracts})
    else
      {:params, {:error, error}} ->
        conn
        |> put_status(400)
        |> render(:error, error: error)
    end
  end

  def getabi(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param),
         {:contract, {:ok, contract}} <- to_smart_contract(address_hash, AccessHelper.conn_to_ip_string(conn)) do
      render(conn, :getabi, %{abi: contract.abi})
    else
      {:address_param, :error} ->
        render(conn, :error, error: @address_required)

      {:format, :error} ->
        render(conn, :error, error: @invalid_address)

      {:contract, :not_found} ->
        render(conn, :error, error: "Contract source code not verified")
    end
  end

  def getsourcecode(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param) do
      _ = PublishHelper.check_and_verify(address_param, ip: AccessHelper.conn_to_ip_string(conn))
      address = Contracts.address_hash_to_address_with_source_code(address_hash)

      render(conn, :getsourcecode, %{
        contract: address || %Address{hash: address_hash, smart_contract: nil}
      })
    else
      {:address_param, :error} ->
        render(conn, :error, error: @address_required)

      {:format, :error} ->
        render(conn, :error, error: @invalid_address)
    end
  end

  defp list_contracts(%{page_number: page_number, page_size: page_size} = opts) do
    offset = (max(page_number, 1) - 1) * page_size

    case Map.get(opts, :filter) do
      :verified ->
        Contracts.list_verified_contracts(page_size, offset, opts)

      :unverified ->
        Contracts.list_unordered_unverified_contracts(page_size, offset)

      :empty ->
        Contracts.list_empty_contracts(page_size, offset)

      _ ->
        Contracts.list_contracts(page_size, offset)
    end
  end

  defp add_filters(options, params) do
    options
    |> add_filter(params)
    |> AddressController.put_timestamp(params, "verified_at_start_timestamp")
    |> AddressController.put_timestamp(params, "verified_at_end_timestamp")
  end

  defp add_filter(options, params) do
    with {:param, {:ok, value}} <- {:param, Map.fetch(params, "filter")},
         {:validation, {:ok, filter}} <- {:validation, contracts_filter(value)} do
      {:ok, Map.put(options, :filter, filter)}
    else
      {:param, :error} -> {:ok, options}
      {:validation, {:error, error}} -> {:error, error}
    end
  end

  defp contracts_filter(nil), do: {:ok, nil}
  defp contracts_filter(1), do: {:ok, :verified}
  defp contracts_filter(2), do: {:ok, :unverified}
  defp contracts_filter(3), do: {:ok, :empty}
  defp contracts_filter("verified"), do: {:ok, :verified}
  defp contracts_filter("unverified"), do: {:ok, :unverified}
  defp contracts_filter("empty"), do: {:ok, :empty}

  defp contracts_filter(filter) when is_bitstring(filter) do
    case Integer.parse(filter) do
      {number, ""} -> contracts_filter(number)
      _ -> {:error, contracts_filter_error_message(filter)}
    end
  end

  defp contracts_filter(filter), do: {:error, contracts_filter_error_message(filter)}

  defp contracts_filter_error_message(filter) do
    "#{filter} is not a valid value for `filter`. Please use one of: verified, unverified, 1, 2."
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_smart_contract(address_hash, ip) do
    _ = PublishHelper.check_and_verify(Hash.to_string(address_hash), ip: ip)

    result =
      case SmartContract.address_hash_to_smart_contract_with_bytecode_twin(address_hash) do
        {nil, _} ->
          :not_found

        {contract, _} ->
          {:ok, contract}
      end

    {:contract, result}
  end

  defp fetch_verify_params(params) do
    {:ok, %{}}
    |> required_param(params, "addressHash", "address_hash")
    |> required_param(params, "name", "name")
    |> required_param(params, "compilerVersion", "compiler_version")
    |> required_param(params, "optimization", "optimization")
    |> required_param(params, "contractSourceCode", "contract_source_code")
    |> optional_param(params, "evmVersion", "evm_version")
    |> optional_param(params, "constructorArguments", "constructor_arguments")
    |> optional_param(params, "autodetectConstructorArguments", "autodetect_constructor_args")
    |> optional_param(params, "optimizationRuns", "optimization_runs")
    |> parse_optimization_runs()
  end

  defp fetch_vyper_verify_params(params) do
    {:ok, %{}}
    |> required_param(params, "addressHash", "address_hash")
    |> required_param(params, "name", "name")
    |> required_param(params, "compilerVersion", "compiler_version")
    |> required_param(params, "contractSourceCode", "contract_source_code")
    |> optional_param(params, "constructorArguments", "constructor_arguments")
  end

  defp fetch_verifysourcecode_params(params) do
    {:ok, %{}}
    |> required_param(params, "contractaddress", "address_hash")
    |> required_param(params, "contractname", "name")
    |> required_param(params, "compilerversion", "compiler_version")
    |> optional_param(params, "constructorArguments", "constructor_arguments")
    |> optional_param(params, "licenseType", "license_type")
    |> (&if(Application.get_env(:explorer, :chain_type) == :zksync,
          do: optional_param(&1, params, "zksolcVersion", "zk_compiler_version"),
          else: &1
        )).()
  end

  defp fetch_verifysourcecode_solidity_single_file_params(params) do
    {:ok, %{}}
    |> required_param(params, "contractaddress", "address_hash")
    |> required_param(params, "contractname", "name")
    |> required_param(params, "compilerversion", "compiler_version")
    |> required_param(params, "optimizationUsed", "optimization")
    |> required_param(params, "sourceCode", "contract_source_code")
    |> optional_param(params, "runs", "optimization_runs")
    |> optional_param(params, "evmversion", "evm_version")
    |> optional_param(params, "constructorArguments", "constructor_arguments")
    |> optional_param(params, "licenseType", "license_type")
    |> prepare_optimization()
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_bitstring(runs) do
    case Integer.parse(runs) do
      {runs_int, _} ->
        {:ok, Map.put(opts, "optimization_runs", runs_int)}

      _ ->
        {:ok, Map.put(opts, "optimization_runs", @optimization_runs)}
    end
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_integer(runs) do
    {:ok, opts}
  end

  defp parse_optimization_runs({:ok, opts}) do
    {:ok, Map.put(opts, "optimization_runs", @optimization_runs)}
  end

  defp parse_optimization_runs(other), do: other

  defp fetch_external_libraries(params) do
    fetch_external_libraries_general(&"library#{&1}Name", &"library#{&1}Address", params)
  end

  defp fetch_external_libraries_for_verifysourcecode(params) do
    fetch_external_libraries_general(&"libraryname#{&1}", &"libraryaddress#{&1}", params)
  end

  defp fetch_external_libraries_general(number_to_library_name, number_to_library_address, params) do
    Enum.reduce(1..Application.get_env(:block_scout_web, :contract)[:verification_max_libraries], %{}, fn number, acc ->
      case Map.fetch(params, number_to_library_name.(number)) do
        {:ok, library_name} ->
          library_address = Map.get(params, number_to_library_address.(number))

          acc
          |> Map.put("library#{number}_name", library_name)
          |> Map.put("library#{number}_address", library_address)

        :error ->
          acc
      end
    end)
  end

  defp required_param({:error, _} = error, _, _, _), do: error

  defp required_param({:ok, map}, params, key, new_key) do
    case Map.fetch(params, key) do
      {:ok, value} ->
        {:ok, Map.put(map, new_key, value)}

      :error ->
        {:error, "#{key} is required."}
    end
  end

  defp optional_param({:error, _} = error, _, _, _), do: error

  defp optional_param({:ok, map}, params, key, new_key) do
    case Map.fetch(params, key) do
      {:ok, value} ->
        {:ok, Map.put(map, new_key, value)}

      :error ->
        {:ok, map}
    end
  end

  defp prepare_optimization({:ok, %{"optimization" => optimization} = params}) do
    parsed = parse_optimization(optimization)

    case parsed do
      :error ->
        {:error, "optimizationUsed has invalid format"}

      _ ->
        {:ok, Map.put(params, "optimization", parsed)}
    end
  end

  defp prepare_optimization(error), do: error

  defp parse_optimization("0"), do: false
  defp parse_optimization(0), do: false

  defp parse_optimization("1"), do: true
  defp parse_optimization(1), do: true

  defp parse_optimization("false"), do: false
  defp parse_optimization(false), do: false

  defp parse_optimization("true"), do: true
  defp parse_optimization(true), do: true

  defp parse_optimization(_), do: :error

  @doc """
   Checks if this valid address hash string, and this address is not prohibited address.
   Returns the `{:ok, address_hash, address}` if address hash passed all the checks.
  """
  @spec validate_address(String.t(), any(), Keyword.t()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:ok, Hash.t(), Address.t()}
  def validate_address(address_hash_string, params, options \\ @api_true) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <- {:not_found, Chain.hash_to_address(address_hash, options)} do
      {:ok, address_hash, address}
    end
  end
end
