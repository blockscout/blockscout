defmodule Indexer.Fetcher.OnDemand.TokenMetadataRefetch do
  @moduledoc """
  Re-fetches token metadata.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Token
  alias Explorer.Chain.Token.Instance, as: TokenInstance

  @spec trigger_refetch(Token.t()) :: :ok
  def trigger_refetch(token) do
    GenServer.cast(__MODULE__, {:refetch, token})
  end

  defp fetch_metadata(token, _state) do
    TokenInstance.drop_metadata(token.contract_address_hash)
  end

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl true
  def handle_cast({:refetch, token}, state) do
    fetch_metadata(token, state)

    {:noreply, state}
  end
end
