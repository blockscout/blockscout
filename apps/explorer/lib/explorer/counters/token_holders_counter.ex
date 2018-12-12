defmodule Explorer.Counters.TokenHoldersCounter do
  use GenServer

  @moduledoc """
  Caches the number of token holders of a token.
  """

  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @table :token_holders_counter

  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  config = Application.get_env(:explorer, Explorer.Counters.TokenHoldersCounter)
  @enable_consolidation Keyword.get(config, :enable_consolidation)

  def table_name do
    @table
  end

  @doc """
  Starts a process to periodically update the counter of the token holders.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server
  @impl true
  def init(args) do
    create_table()

    if enable_consolidation?() do
      Task.start_link(&consolidate/0)
      schedule_next_consolidation()
    end

    {:ok, args}
  end

  def create_table do
    opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true
    ]

    :ets.new(table_name(), opts)
  end

  @doc """
  Consolidates the token holders info, by populating the `:ets` table with the current database information.
  """
  def consolidate do
    TokenBalance.tokens_grouped_by_number_of_holders()
    |> Repo.stream_each(fn {%Hash{bytes: bytes}, number_of_holders} ->
      insert_counter({bytes, number_of_holders})
    end)
  end

  defp schedule_next_consolidation do
    if enable_consolidation?() do
      # Schedule next consolidation to be run in 30 minutes
      Process.send_after(self(), :consolidate, 30 * 60 * 1000)
    end
  end

  @doc """
  Fetches the token holders info for a specific token from the `:ets` table.
  """
  def fetch(%Hash{bytes: bytes}) do
    do_fetch(:ets.lookup(table_name(), bytes))
  end

  defp do_fetch([{_, result}]), do: result
  defp do_fetch([]), do: 0

  @doc """
  Inserts new items into the `:ets` table.
  """
  def insert_counter(token_holders) do
    :ets.insert(table_name(), token_holders)
  end

  @impl true
  def handle_info(:consolidate, state) do
    consolidate()

    schedule_next_consolidation()

    {:noreply, state}
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Counters.TokenHoldersCounter, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Counters.TokenHoldersCounter, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
