defmodule Explorer.Indexer.BlockImporter do
  @moduledoc """
  Imports blocks to the chain.

  Batched block ranges are serialized through the importer to avoid
  races and lock contention against conurrent address upserts.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Indexer.AddressFetcher

  def import_blocks(blocks) do
    GenServer.call(__MODULE__, {:import, blocks})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_call({:import, blocks}, _from, state) do
    case Chain.import_blocks(blocks) do
      {:ok, %{addresses: address_hashes}} ->
        :ok = AddressFetcher.async_fetch_balances(address_hashes)
        {:reply, :ok, state}

      {:error, step, reason, _changes} ->
        {:reply, {:error, step, reason}, state}
    end
  end
end
