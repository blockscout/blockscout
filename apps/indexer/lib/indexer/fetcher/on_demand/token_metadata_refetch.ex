# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.TokenMetadataRefetch do
  @moduledoc """
  Re-fetches fungible token metadata.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Token
  alias Explorer.Utility.RateLimiter
  alias Indexer.Fetcher.TokenUpdater

  @spec trigger_refetch(String.t() | nil, Token.t()) :: :ok
  def trigger_refetch(caller \\ nil, token) do
    case RateLimiter.check_rate(caller, :on_demand) do
      :allow -> GenServer.cast(__MODULE__, {:refetch, token})
      :deny -> :ok
    end
  end

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, json_rpc_named_arguments}
  end

  @impl true
  def handle_cast({:refetch, token}, json_rpc_named_arguments) do
    Task.Supervisor.start_child(__MODULE__.TaskSupervisor, fn ->
      TokenUpdater.run([token], json_rpc_named_arguments)
    end)

    {:noreply, json_rpc_named_arguments}
  end
end
