defmodule BlockScoutWeb.API.RPC.ContractController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.Helpers
  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Publisher

  def verify(conn, %{"addressHash" => address_hash} = params) do
    with {:params, {:ok, fetched_params}} <- {:params, fetch_verify_params(params)},
         {:format, {:ok, casted_address_hash}} <- to_address_hash(address_hash),
         {:params, external_libraries} <-
           {:params, fetch_external_libraries(params)},
         {:publish, {:ok, _}} <-
           {:publish, Publisher.publish(address_hash, fetched_params, external_libraries)} do
      address = Chain.address_hash_to_address_with_source_code(casted_address_hash)

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
      address = Chain.address_hash_to_address_with_source_code(address_hash)

      render(conn, :getsourcecode, %{
        contract: address
      })
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
        Chain.list_verified_contracts(page_size, offset)

      :decompiled ->
        not_decompiled_with_version = Map.get(opts, :not_decompiled_with_version)
        Chain.list_decompiled_contracts(page_size, offset, not_decompiled_with_version)

      :unverified ->
        Chain.list_unordered_unverified_contracts(page_size, offset)

      :not_decompiled ->
        Chain.list_unordered_not_decompiled_contracts(page_size, offset)

      :empty ->
        Chain.list_empty_contracts(page_size, offset)

      _ ->
        Chain.list_contracts(page_size, offset)
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
    |> optional_param(params, "autodetectConstructorArguments", "autodetect_contructor_args")
    |> optional_param(params, "optimizationRuns", "optimization_runs")
    |> parse_optimization_runs()
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_bitstring(runs) do
    {:ok, Map.put(opts, "optimization_runs", 200)}
  end

  defp parse_optimization_runs({:ok, %{"optimization_runs" => runs} = opts}) when is_integer(runs) do
    {:ok, opts}
  end

  defp parse_optimization_runs({:ok, opts}) do
    {:ok, Map.put(opts, "optimization_runs", 200)}
  end

  defp parse_optimization_runs(other), do: other

  defp fetch_external_libraries(params) do
    Enum.reduce(1..5, %{}, fn number, acc ->
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
