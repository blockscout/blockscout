defmodule Indexer.Fetcher.OnDemand.NFTCollectionMetadataRefetch do
  @moduledoc """
  Re-fetches token metadata.
  """

  require Logger

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain.Token
  alias Explorer.Chain.Token.Instance, as: TokenInstance
  alias Explorer.Utility.RateLimiter

  @spec trigger_refetch(String.t() | nil, Token.t()) :: :ok
  def trigger_refetch(caller \\ nil, token) do
    case RateLimiter.check_rate(caller, :on_demand) do
      :allow -> GenServer.cast(__MODULE__, {:refetch, token})
      :deny -> :ok
    end
  end

  defp fetch_metadata(token) do
    TokenInstance.mark_nft_collection_to_refetch(token.contract_address_hash)
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
    fetch_metadata(token)

    {:noreply, state}
  end
end
