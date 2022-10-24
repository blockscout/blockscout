defmodule BlockScoutWeb.API.RPC.ContractController do
  use BlockScoutWeb, :controller

  require Logger

  alias BlockScoutWeb.AddressContractVerificationViaJsonController, as: VerificationController
  alias BlockScoutWeb.API.RPC.Helpers
  alias Explorer.Chain
  alias Explorer.Chain.Events.Publisher, as: EventsPublisher
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.Chain.SmartContract.VerificationStatus
  alias Explorer.Etherscan.Contracts
  alias Explorer.SmartContract.Solidity.Publisher
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher
  alias Explorer.ThirdPartyIntegrations.Sourcify

  def verify(conn, %{"addressHash" => address_hash} = params) do
    with {:params, {:ok, fetched_params}} <- {:params, fetch_verify_params(params)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:params, external_libraries} <-
           {:params, fetch_external_libraries(params)},
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
        render(conn, :error, error: "Smart-contract already verified.")

      {:publish, _} ->
        render(conn, :error, error: "Something went wrong while publishing the contract.")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash")

      {:params, {:error, error}} ->
        render(conn, :error, error: error)
    end
  end

  def verify_via_sourcify(conn, %{"addressHash" => address_hash} = input) do
    files =
      if Map.has_key?(input, "files") do
        input["files"]
      else
        []
      end

    if Chain.smart_contract_fully_verified?(address_hash) do
      render(conn, :error, error: "Smart-contract already verified.")
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

            _ ->
              render(conn, :error, error: "Invalid body")
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
           {:check_verified_status, Chain.smart_contract_fully_verified?(address_hash)},
         {:format, {:ok, _casted_address_hash}} <- to_address_hash(address_hash),
         {:params, {:ok, fetched_params}} <- {:params, fetch_verifysourcecode_params(params)},
         uid <- VerificationStatus.generate_uid(address_hash) do
      Que.add(SolidityPublisherWorker, {fetched_params, json_input, uid})

      render(conn, :show, %{result: uid})
    else
      {:check_verified_status, true} ->
        render(conn, :error, error: "Smart-contract already verified.", data: "Smart-contract already verified")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash", data: "Invalid address hash")

      {:params, {:error, error}} ->
        render(conn, :error, error: error, data: error)
    end
  end

  def verifysourcecode(conn, %{"codeformat" => "solidity-standard-json-input"}) do
    render(conn, :error, error: "Missing sourceCode or contractaddress fields")
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

  defp prepare_params(files) when is_struct(files) do
    {:error, "Invalid args format"}
  end

  defp prepare_params(files) when is_map(files) do
    {:ok, VerificationController.prepare_files_array(files)}
  end

  defp prepare_params(files) when is_list(files) do
    {:ok, files}
  end

  defp prepare_params(_arg) do
    {:error, "Invalid args format"}
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
        |> Enum.filter(fn file -> only_json(file.filename) end)

      sols =
        files_array
        |> Enum.filter(fn file -> only_sol(file.filename) end)

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

  defp only_sol(filename) do
    case List.last(String.split(String.downcase(filename), ".")) do
      "sol" ->
        true

      _ ->
        false
    end
  end

  defp only_json(filename) do
    case List.last(String.split(String.downcase(filename), ".")) do
      "json" ->
        true

      _ ->
        false
    end
  end

  defp get_metadata_and_publish(address_hash_string, conn) do
    case Sourcify.get_metadata(address_hash_string) do
      {:ok, verification_metadata} ->
        %{"params_to_publish" => params_to_publish, "abi" => abi, "secondary_sources" => secondary_sources} =
          Sourcify.parse_params_from_sourcify(address_hash_string, verification_metadata)

        case publish_without_broadcast(%{
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

      {:error, %{"error" => error}} ->
        render(conn, :error, error: error)
    end
  end

  defp verify_and_publish(address_hash_string, files_array, conn) do
    case Sourcify.verify(address_hash_string, files_array) do
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
        render(conn, :error, error: "Smart-contract already verified.")

      {:publish, _} ->
        render(conn, :error, error: "Something went wrong while publishing the contract.")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash")

      {:params, {:error, error}} ->
        render(conn, :error, error: error)
    end
  end

  def publish_without_broadcast(
        %{"addressHash" => address_hash, "abi" => abi, "compilationTargetFilePath" => file_path} = input
      ) do
    params = proccess_params(input)

    address_hash
    |> Publisher.publish_smart_contract(params, abi, file_path)
    |> proccess_response()
  end

  def publish_without_broadcast(%{"addressHash" => address_hash, "abi" => abi} = input) do
    params = proccess_params(input)

    address_hash
    |> Publisher.publish_smart_contract(params, abi)
    |> proccess_response()
  end

  def publish(nil, %{"addressHash" => _address_hash} = input) do
    publish_without_broadcast(input)
  end

  def publish(conn, %{"addressHash" => address_hash} = input) do
    result = publish_without_broadcast(input)

    EventsPublisher.broadcast([{:contract_verification_result, {address_hash, result, conn}}], :on_demand)
    result
  end

  def proccess_params(input) do
    if Map.has_key?(input, "secondarySources") do
      input["params"]
      |> Map.put("secondary_sources", Map.get(input, "secondarySources"))
    else
      input["params"]
    end
  end

  def proccess_response(response) do
    case response do
      {:ok, _contract} = result ->
        result

      {:error, changeset} ->
        {:error, changeset}

      {:update_submitted} ->
        :update_submitted
    end
  end

  def listcontracts(conn, params) do
    with pagination_options <- Helpers.put_pagination_options(%{}, params),
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
         {:contract, {:ok, contract}} <- to_smart_contract(address_hash) do
      render(conn, :getabi, %{abi: contract.abi})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash")

      {:contract, :not_found} ->
        render(conn, :error, error: "Contract source code not verified")
    end
  end

  def getsourcecode(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, address_hash}} <- to_address_hash(address_param) do
      ignore_proxy = Map.get(params, "ignoreProxy", "0")
      Logger.debug("Ignore proxy flag set to #{ignore_proxy} and #{is_integer(ignore_proxy)}}")

      _ = VerificationController.check_and_verify(address_param)

      address =
        if ignore_proxy == "1" do
          Logger.debug("Not checking if contract is proxied")
          Contracts.address_hash_to_address_with_source_code(address_hash)
        else
          case Contracts.get_proxied_address(address_hash) do
            {:ok, proxy_contract} ->
              Logger.debug("Implementation address found in proxy table")
              Contracts.address_hash_to_address_with_source_code(proxy_contract)

            {:error, :not_found} ->
              Logger.debug("Implementation address not found in proxy table")
              Contracts.address_hash_to_address_with_source_code(address_hash)
          end
        end

      render(
        conn,
        :getsourcecode,
        %{
          contract: address
        }
      )
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address hash")

      {:contract, :not_found} ->
        render(conn, :getsourcecode, %{contract: nil, address_hash: nil})
    end
  end

  defp list_contracts(%{page_number: page_number, page_size: page_size} = opts) do
    offset = (max(page_number, 1) - 1) * page_size

    case Map.get(opts, :filter) do
      :verified ->
        Contracts.list_verified_contracts(page_size, offset)

      :decompiled ->
        not_decompiled_with_version = Map.get(opts, :not_decompiled_with_version)
        Contracts.list_decompiled_contracts(page_size, offset, not_decompiled_with_version)

      :unverified ->
        Contracts.list_unordered_unverified_contracts(page_size, offset)

      :not_decompiled ->
        Contracts.list_unordered_not_decompiled_contracts(page_size, offset)

      :empty ->
        Contracts.list_empty_contracts(page_size, offset)

      _ ->
        Contracts.list_contracts(page_size, offset)
    end
  end

  defp add_filters(options, params) do
    options
    |> add_filter(params)
    |> add_not_decompiled_with_version(params)
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

  defp add_not_decompiled_with_version({:ok, options}, params) do
    case Map.fetch(params, "not_decompiled_with_version") do
      {:ok, value} -> {:ok, Map.put(options, :not_decompiled_with_version, value)}
      :error -> {:ok, options}
    end
  end

  defp add_not_decompiled_with_version(options, _params) do
    options
  end

  defp contracts_filter(nil), do: {:ok, nil}
  defp contracts_filter(1), do: {:ok, :verified}
  defp contracts_filter(2), do: {:ok, :decompiled}
  defp contracts_filter(3), do: {:ok, :unverified}
  defp contracts_filter(4), do: {:ok, :not_decompiled}
  defp contracts_filter(5), do: {:ok, :empty}
  defp contracts_filter("verified"), do: {:ok, :verified}
  defp contracts_filter("decompiled"), do: {:ok, :decompiled}
  defp contracts_filter("unverified"), do: {:ok, :unverified}
  defp contracts_filter("not_decompiled"), do: {:ok, :not_decompiled}
  defp contracts_filter("empty"), do: {:ok, :empty}

  defp contracts_filter(filter) when is_bitstring(filter) do
    case Integer.parse(filter) do
      {number, ""} -> contracts_filter(number)
      _ -> {:error, contracts_filter_error_message(filter)}
    end
  end

  defp contracts_filter(filter), do: {:error, contracts_filter_error_message(filter)}

  defp contracts_filter_error_message(filter) do
    "#{filter} is not a valid value for `filter`. Please use one of: verified, decompiled, unverified, not_decompiled, 1, 2, 3, 4."
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  defp to_smart_contract(address_hash) do
    _ = VerificationController.check_and_verify(Hash.to_string(address_hash))

    result =
      case Chain.address_hash_to_smart_contract(address_hash) do
        nil ->
          :not_found

        contract ->
          {:ok, SmartContract.preload_decompiled_smart_contract(contract)}
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
    |> optional_param(params, "proxyAddress", "proxy_address")
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
    |> optional_param(params, "constructorArguements", "constructor_arguments")
    |> optional_param(params, "constructorArguments", "constructor_arguments")
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_bitstring(runs) do
    case Integer.parse(runs) do
      {runs_int, _} ->
        {:ok, Map.put(opts, "optimization_runs", runs_int)}

      _ ->
        {:ok, Map.put(opts, "optimization_runs", 200)}
    end
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_integer(runs) do
    {:ok, opts}
  end

  defp parse_optimization_runs({:ok, opts}) do
    {:ok, Map.put(opts, "optimization_runs", 200)}
  end

  defp parse_optimization_runs(other), do: other

  defp fetch_external_libraries(params) do
    Enum.reduce(1..10, %{}, fn number, acc ->
      case Map.fetch(params, "library#{number}Name") do
        {:ok, library_name} ->
          library_address = Map.get(params, "library#{number}Address")

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
end
