defmodule Explorer.TokenInstanceOwnerAddressMigration.Worker do
  @moduledoc """
    GenServer for filling  owner_address_hash, owner_updated_at_block and owner_updated_at_log_index
    for ERC-721 token instances. Works in the following way
    1. Checks if there are some unprocessed nfts.
      - if yes, then go to 2 stage
      - if no, then shutdown
    2. Fetch `(concurrency * batch_size)` token instances, process them in `concurrency` tasks.
    3. Go to step 1
  """

  use GenServer, restart: :transient

  alias Explorer.Repo
  alias Explorer.TokenInstanceOwnerAddressMigration.Helper

  def start_link(concurrency: concurrency, batch_size: batch_size, enabled: _) do
    GenServer.start_link(__MODULE__, %{concurrency: concurrency, batch_size: batch_size}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    GenServer.cast(__MODULE__, :check_necessity)

    {:ok, opts}
  end

  @impl true
  def handle_cast(:check_necessity, state) do
    if Helper.unfilled_token_instances_exists?() do
      GenServer.cast(__MODULE__, :backfill)
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  @impl true
  def handle_cast(:backfill, %{concurrency: concurrency, batch_size: batch_size} = state) do
    (concurrency * batch_size)
    |> Helper.filtered_token_instances_query()
    |> Repo.all()
    |> Enum.chunk_every(batch_size)
    |> Enum.map(fn batch -> Task.async(fn -> Helper.fetch_and_insert(batch) end) end)
    |> Task.await_many(:infinity)

    GenServer.cast(__MODULE__, :check_necessity)

    {:noreply, state}
  end
end
