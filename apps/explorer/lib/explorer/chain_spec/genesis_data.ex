defmodule Explorer.ChainSpec.GenesisData do
  @moduledoc """
  Handles the genesis data import.

  This module is responsible for managing the import of genesis data into the
  database, which includes pre-mined balances and precompiled smart contract
  bytecodes.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.SmartContract
  alias Explorer.ChainSpec.Geth.Importer, as: GethImporter
  alias Explorer.ChainSpec.Parity.Importer
  alias Explorer.HttpClient
  alias Utils.ConfigHelper, as: UtilsConfigHelper

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Process.send_after(self(), :import, Application.get_env(:explorer, __MODULE__)[:genesis_processing_delay])

    {:ok, %{}}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {:error, reason}}, state) do
    Logger.warning(fn -> "Failed to fetch and import genesis data or precompiled contracts: '#{reason}'." end)

    fetch_genesis_data()

    {:noreply, state}
  end

  # Initiates the import of genesis data.
  #
  # This function triggers the fetching and importing of genesis data, including pre-mined balances and precompiled smart contract bytecodes.
  #
  # ## Parameters
  # - `:import`: The message that triggers this function.
  # - `state`: The current state of the GenServer.
  #
  # ## Returns
  # - `{:noreply, state}`
  @impl GenServer
  def handle_info(:import, state) do
    Logger.debug(fn -> "Importing genesis data" end)

    fetch_genesis_data()

    {:noreply, state}
  end

  # Callback that a monitored process has shutdown
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, _}, state) do
    {:noreply, state}
  end

  @doc """
    Fetches and processes the genesis data, which includes pre-mined balances and precompiled smart contract bytecodes.

    This function retrieves the chain specification and precompiled contracts
    configuration from specified paths in the application settings. Then it
    asynchronously extends the chain spec with precompiled contracts, imports
    genesis accounts, and the precompiled contracts' sources and ABIs.

    ## Returns
    - `Task.t()`: A task handle if the fetch and processing are scheduled successfully.
    - `:ok`: Indicates no fetch was attempted due to missing configuration paths.
  """
  @spec fetch_genesis_data() :: Task.t() | :ok
  def fetch_genesis_data do
    chain_spec_path = get_path(:chain_spec_path)
    Logger.info(fn -> "Fetching chain spec path: #{inspect(chain_spec_path)}." end)
    precompiled_config_path = get_path(:precompiled_config_path)
    Logger.info(fn -> "Fetching precompiled config path: #{inspect(precompiled_config_path)}." end)

    if is_nil(chain_spec_path) and is_nil(precompiled_config_path) do
      Logger.warning(fn ->
        "Genesis data is not fetched. Neither chain spec path or precompiles config path are set."
      end)
    else
      json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
        chain_spec = fetch_chain_spec(chain_spec_path)
        precompiles_config = fetch_precompiles_config(precompiled_config_path)

        extended_chain_spec = extend_chain_spec(chain_spec, precompiles_config, variant)
        import_genesis_accounts(extended_chain_spec, variant)

        import_precompiles_sources_and_abi(precompiles_config)
      end)
    end
  end

  @spec get_path(atom()) :: nil | binary()
  defp get_path(key) do
    case Application.get_env(:explorer, __MODULE__)[key] do
      nil -> nil
      value when is_binary(value) -> value
    end
  end

  # Retrieves the chain specification, returning an empty map if unsuccessful.
  @spec fetch_chain_spec(binary() | nil) :: map() | list()
  defp fetch_chain_spec(path) do
    case do_fetch(path, "Failed to fetch chain spec.") do
      nil -> %{}
      value -> value
    end
  end

  # Retrieves the precompiled contracts configuration, returning an empty list if unsuccessful.
  @spec fetch_precompiles_config(binary() | nil) :: list()
  defp fetch_precompiles_config(path) do
    case do_fetch(path, "Failed to fetch precompiles config.") do
      nil -> []
      value -> value
    end
  end

  # Fetches JSON data from a specified path.
  @spec do_fetch(binary() | nil, binary()) :: list() | map() | nil
  defp do_fetch(path, warn_message_prefix) do
    if path do
      case fetch_spec_as_json(path) do
        {:ok, chain_spec} ->
          chain_spec

        {:error, reason} ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          Logger.warning(fn -> "#{warn_message_prefix} #{inspect(reason)}" end)
          nil
      end
    else
      nil
    end
  end

  # Retrieves a JSON data from either a file or URL based on the source.
  @spec fetch_spec_as_json(binary()) :: {:ok, list() | map()} | {:error, any()}
  defp fetch_spec_as_json(path) do
    if UtilsConfigHelper.valid_url?(path) do
      fetch_from_url(path)
    else
      fetch_from_file(path)
    end
  end

  # Reads and parses JSON data from a file.
  @spec fetch_from_file(binary()) :: {:ok, list() | map()} | {:error, Jason.DecodeError.t()}
  # sobelow_skip ["Traversal"]
  defp fetch_from_file(path) do
    with {:ok, data} <- File.read(path) do
      Jason.decode(data)
    end
  end

  # Fetches JSON data from a provided URL.
  @spec fetch_from_url(binary()) :: {:ok, list() | map()} | {:error, Jason.DecodeError.t() | any()}
  defp fetch_from_url(url) do
    case HttpClient.get(url, [], timeout: 60_000, recv_timeout: 60_000) do
      {:ok, %{body: body, status_code: 200}} ->
        {:ok, Jason.decode!(body)}

      reason ->
        {:error, reason}
    end
  end

  # Extends the chain specification with precompiled contract information.
  #
  # This function modifies the chain specification to include precompiled
  # contracts that are not originally listed in the spec. It handles different
  # formats of chain specs (list or map) according to the `variant` specified
  # and adds precompiles.
  #
  # ## Parameters
  # - `chain_spec`: The original chain specification in map or list format.
  # - `precompiles_config`: A list of precompiled contracts to be added.
  # - `variant`: The client variant (e.g., Geth or Parity), which dictates the
  #   spec structure.
  #
  # ## Returns
  # - The modified chain specification with precompiled contracts included.
  @spec extend_chain_spec(map() | list(), list(), EthereumJSONRPC.Geth | EthereumJSONRPC.Parity) :: map() | list()
  defp extend_chain_spec(chain_spec, [], _) do
    chain_spec
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Geth.Importer
  defp extend_chain_spec(chain_spec, precompiles_config, variant)
       when is_list(chain_spec) and variant in [EthereumJSONRPC.Geth, EthereumJSONRPC.Besu] do
    precompiles_as_map =
      precompiles_config
      |> Enum.reduce(%{}, fn contract, acc ->
        Map.put(acc, contract["address"], %{
          "address" => contract["address"],
          "balance" => 0,
          "bytecode" => contract["bytecode"]
        })
      end)

    filtered_maps_of_precompiles =
      chain_spec
      |> Enum.reduce(precompiles_as_map, fn account, acc ->
        Map.delete(acc, account["address"])
      end)

    chain_spec ++ Map.values(filtered_maps_of_precompiles)
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Geth.Importer
  defp extend_chain_spec(%{"genesis" => sub_entity} = chain_spec, precompiles_config, variant)
       when variant in [EthereumJSONRPC.Geth, EthereumJSONRPC.Besu] do
    updated_sub_entity = extend_chain_spec(sub_entity, precompiles_config, variant)

    Map.put(chain_spec, "genesis", updated_sub_entity)
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Geth.Importer
  defp extend_chain_spec(chain_spec, precompiles_config, variant)
       when is_map(chain_spec) and variant in [EthereumJSONRPC.Geth, EthereumJSONRPC.Besu] do
    accounts =
      case chain_spec["alloc"] do
        nil -> %{}
        value -> value
      end

    updated_accounts =
      precompiles_config
      |> Enum.reduce(accounts, fn contract, acc ->
        Map.put_new(acc, contract["address"], %{"balance" => 0, "code" => contract["bytecode"]})
      end)

    Map.put(chain_spec, "alloc", updated_accounts)
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Parity.Importer
  defp extend_chain_spec(chain_spec, precompiles_config, _) when is_map(chain_spec) do
    accounts =
      case chain_spec["accounts"] do
        nil -> %{}
        value -> value
      end

    updated_accounts =
      precompiles_config
      |> Enum.reduce(accounts, fn contract, acc ->
        Map.put_new(acc, contract["address"], %{"balance" => 0, "constructor" => contract["bytecode"]})
      end)

    Map.put(chain_spec, "accounts", updated_accounts)
  end

  # Imports genesis accounts from the specified chain specification and updates
  # `Explorer.Chain.Address` and `Explorer.Chain.Address.CoinBalance`, and
  # `Explorer.Chain.Address.CoinBalanceDaily`.
  @spec import_genesis_accounts(map() | list(), EthereumJSONRPC.Geth | EthereumJSONRPC.Parity) :: any()
  defp import_genesis_accounts(chain_spec, variant) do
    if not Enum.empty?(chain_spec) do
      case variant do
        variant when variant in [EthereumJSONRPC.Geth, EthereumJSONRPC.Besu] ->
          {:ok, _} = GethImporter.import_genesis_accounts(chain_spec)

        _ ->
          Importer.import_emission_rewards(chain_spec)
          {:ok, _} = Importer.import_genesis_accounts(chain_spec)
      end
    end
  end

  # Iterates through the list of precompiles descriptions, and creating/updating
  # each smart contract.
  @spec import_precompiles_sources_and_abi([map()]) :: any()
  defp import_precompiles_sources_and_abi(precompiles_config) do
    precompiles_config
    |> Enum.each(fn contract ->
      attrs = %{
        address_hash: contract["address"],
        name: contract["name"],
        file_path: nil,
        # todo: process zksync zk_compiler
        compiler_version: contract["compiler"],
        evm_version: nil,
        optimization_runs: nil,
        optimization: false,
        contract_source_code: contract["source"],
        constructor_arguments: nil,
        external_libraries: [],
        secondary_sources: [],
        abi: Jason.decode!(contract["abi"]),
        verified_via_sourcify: false,
        verified_via_eth_bytecode_db: false,
        verified_via_verifier_alliance: false,
        partially_verified: false,
        autodetect_constructor_args: nil,
        compiler_settings: nil,
        license_type: :none
      }

      SmartContract.create_or_update_smart_contract(contract["address"], attrs, false)
    end)
  end
end
