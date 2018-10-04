defmodule Explorer.Counters.TokenTransferCounter do
  use GenServer

  @moduledoc """
  Module responsible for fetching and consolidating the number of transfers
  from a token.
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, TokenTransfer}

  @table :token_transfer_counter

  def table_name do
    @table
  end

  @doc """
  Starts a process to continually monitor the token counters.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server
  @impl true
  def init(args) do
    create_table()

    Task.start_link(&consolidate/0)

    Chain.subscribe_to_events(:token_transfers)

    {:ok, args}
  end

  def create_table do
    opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(table_name(), opts)
  end

  @doc """
  Consolidates the number of token transfers grouped by token.
  """
  def consolidate do
    total_token_transfers = TokenTransfer.count_token_transfers()

    for {token_hash, total} <- total_token_transfers do
      insert_or_update_counter(token_hash, total)
    end
  end

  @doc """
  Fetches the number of transfers related to a token hash.
  """
  @spec fetch(Hash.t()) :: non_neg_integer
  def fetch(token_hash) do
    do_fetch(:ets.lookup(table_name(), to_string(token_hash)))
  end

  defp do_fetch([{_, result} | _]), do: result
  defp do_fetch([]), do: 0

  @impl true
  def handle_info({:chain_event, :token_transfers, _type, token_transfers}, state) do
    token_transfers
    |> Enum.map(& &1.token_contract_address_hash)
    |> Enum.each(&insert_or_update_counter(&1, 1))

    {:noreply, state}
  end

  @doc """
  Inserts a new item into the `:ets` table.

  When the record exist, the counter will be incremented by one. When the
  record does not exist, the counter will be inserted with a default value.
  """
  @spec insert_or_update_counter(Hash.t(), non_neg_integer) :: term()
  def insert_or_update_counter(token_hash, number) do
    default = {to_string(token_hash), 0}

    :ets.update_counter(table_name(), to_string(token_hash), number, default)
  end
end
