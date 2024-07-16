defmodule Indexer.BridgedTokens.SetAmbBridgedMetadataForTokens do
  @moduledoc """
  Sets token metadata for bridged tokens from AMB extensions.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.BridgedToken

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(_opts) do
    send(self(), :process_amb_tokens)

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:process_amb_tokens, state) do
    fetch_amb_bridged_tokens_metadata()

    {:noreply, state}
  end

  # don't handle other messages (e.g. :ssl_closed)
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp fetch_amb_bridged_tokens_metadata do
    :ok = BridgedToken.process_amb_tokens()

    Logger.debug(fn -> "Bridged status fetched for AMB tokens" end)
  end
end
