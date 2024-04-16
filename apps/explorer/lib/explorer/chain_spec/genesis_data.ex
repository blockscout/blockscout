defmodule Explorer.ChainSpec.GenesisData do
  @moduledoc """
  Fetches genesis data.
  """

  use GenServer

  require Logger

  alias Explorer.ChainSpec.Geth.Importer, as: GethImporter
  alias Explorer.ChainSpec.Parity.Importer
  alias Explorer.Helper
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher
  alias HTTPoison.Response

  @interval :timer.minutes(2)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Process.send_after(self(), :import, @interval)

    {:ok, %{}}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {:error, reason}}, state) do
    Logger.warn(fn -> "Failed to fetch genesis data '#{reason}'." end)

    fetch_genesis_data()

    {:noreply, state}
  end

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
  Fetches pre-mined balances and pre-compiled smart-contract bytecodes from genesis.json
  """
  @spec fetch_genesis_data() :: Task.t() | :ok
  def fetch_genesis_data do
    chain_spec_path = get_path(:chain_spec_path)
    precompiled_config_path = get_path(:precompiled_config_path)

    if is_nil(chain_spec_path) and is_nil(precompiled_config_path) do
      Logger.warn(fn -> "Genesis data is not fetched. Neither chain spec path or precompiles config path are set." end)
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

  defp get_path(key) do
    case Application.get_env(:explorer, __MODULE__)[key] do
      nil -> nil
      value when is_binary(value) -> value
    end
  end

  defp fetch_chain_spec(path) do
    case do_fetch(path, "Failed to fetch chain spec.") do
      nil -> %{}
      value -> value
    end
  end

  defp fetch_precompiles_config(path) do
    case do_fetch(path, "Failed to fetch precompiles config.") do
      nil -> []
      value -> value
    end
  end

  defp do_fetch(path, warn_message_prefix) do
    if path do
      case fetch_spec_as_json(path) do
        {:ok, chain_spec} ->
          chain_spec

        {:error, reason} ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          Logger.warn(fn -> "#{warn_message_prefix} #{inspect(reason)}" end)
          nil
      end
    else
      nil
    end
  end

  defp fetch_spec_as_json(path) do
    if Helper.valid_url?(path) do
      fetch_from_url(path)
    else
      fetch_from_file(path)
    end
  end

  # sobelow_skip ["Traversal"]
  defp fetch_from_file(path) do
    with {:ok, data} <- File.read(path) do
      Jason.decode(data)
    end
  end

  defp fetch_from_url(url) do
    case HTTPoison.get(url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, Jason.decode!(body)}

      reason ->
        {:error, reason}
    end
  end

  defp extend_chain_spec(chain_spec, [], _) do
    chain_spec
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Geth.Importer
  defp extend_chain_spec(chain_spec, precompiles_config, variant)
       when is_list(chain_spec) and variant == EthereumJSONRPC.Geth do
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
       when variant == EthereumJSONRPC.Geth do
    updated_sub_entity = extend_chain_spec(sub_entity, precompiles_config, variant)

    Map.put(chain_spec, "genesis", updated_sub_entity)
  end

  # Resulting spec will be handled by Explorer.ChainSpec.Geth.Importer
  defp extend_chain_spec(chain_spec, precompiles_config, variant)
       when is_map(chain_spec) and variant == EthereumJSONRPC.Geth do
    accounts =
      case chain_spec["alloc"] do
        nil -> %{}
        value -> value
      end

    updated_accounts =
      precompiles_config
      |> Enum.reduce(accounts, fn contract, acc ->
        case acc[contract["address"]] do
          nil -> Map.put(acc, contract["address"], %{"balance" => 0, "code" => contract["bytecode"]})
          _ -> acc
        end
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
        case acc[contract["address"]] do
          nil -> Map.put(acc, contract["address"], %{"balance" => 0, "constructor" => contract["bytecode"]})
          _ -> acc
        end
      end)

    Map.put(chain_spec, "accounts", updated_accounts)
  end

  defp import_genesis_accounts(chain_spec, variant) do
    if not Enum.empty?(chain_spec) do
      case variant do
        EthereumJSONRPC.Geth ->
          {:ok, _} = GethImporter.import_genesis_accounts(chain_spec)

        _ ->
          Importer.import_emission_rewards(chain_spec)
          {:ok, _} = Importer.import_genesis_accounts(chain_spec)
      end
    end
  end

  defp import_precompiles_sources_and_abi(precompiles_config) do
    precompiles_config
    |> Enum.each(fn contract ->
      attrs = %{
        address_hash: contract["address"],
        name: contract["name"],
        file_path: nil,
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
        is_vyper_contract: false,
        autodetect_constructor_args: nil,
        is_yul: false,
        compiler_settings: nil,
        license_type: :none
      }

      SolidityPublisher.create_or_update_smart_contract(contract["address"], attrs)
    end)
  end
end
