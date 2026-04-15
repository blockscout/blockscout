defmodule Indexer.Fetcher.Optimism.SuperchainConfigUpdater do
  @moduledoc """
  Runs once on startup to populate Optimism constants from Superchain TOML
  (with env fallback) into the `constants` table.
  """

  use GenServer

  alias Indexer.Fetcher.Optimism.SuperchainConfig

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    if Application.get_env(:explorer, :chain_type) == :optimism do
      SuperchainConfig.refresh()
    end

    :ignore
  end
end
