defmodule Explorer.ChainSpec.GenesisData do
  @moduledoc """
  Fetches genesis data.
  """

  use GenServer

  require Logger

  alias Explorer.ChainSpec.Geth.Importer, as: GethImporter
  alias Explorer.ChainSpec.Parity.Importer
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

  def fetch_genesis_data do
    path = Application.get_env(:explorer, __MODULE__)[:chain_spec_path]

    if path do
      json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
        case fetch_spec(path) do
          {:ok, chain_spec} ->
            case variant do
              EthereumJSONRPC.Nethermind ->
                Importer.import_emission_rewards(chain_spec)
                {:ok, _} = Importer.import_genesis_accounts(chain_spec)

              EthereumJSONRPC.Geth ->
                {:ok, _} = GethImporter.import_genesis_accounts(chain_spec)

              _ ->
                Importer.import_emission_rewards(chain_spec)
                {:ok, _} = Importer.import_genesis_accounts(chain_spec)
            end

          {:error, reason} ->
            # credo:disable-for-next-line
            Logger.warn(fn -> "Failed to fetch genesis data. #{inspect(reason)}" end)
        end
      end)
    else
      Logger.warn(fn -> "Failed to fetch genesis data. Chain spec path is not set." end)
    end
  end

  defp fetch_spec(path) do
    if valid_url?(path) do
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

  defp valid_url?(string) do
    uri = URI.parse(string)

    uri.scheme != nil && uri.host =~ "."
  end
end
