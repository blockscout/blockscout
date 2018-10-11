defmodule Explorer.Counters.TransactionCounter do
  use GenServer

  @moduledoc """
  Module responsible for fetching and consolidating the number of transactions by address.
  """

  alias Explorer.{Chain}
  alias Explorer.Chain.{Address, Transaction}

  @doc """
  Starts a process to continually monitor the transaction counters.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server
  @impl true
  def init(args) do
    Task.start_link(&consolidate/0)

    subscribe_to_events()

    {:ok, args}
  end

  # We don't want to subscribe to events in all environments, for instance, in the test env. Otherwise,
  # the function that is listening the event will execute every time that the event is triggered by
  # another test. As this function can perform an Ecto query, we would need to make sure that this
  # process was finished in every test that can trigger this event.
  #
  # By default the event is enabled. For disabling it, you need to config the enviroment like this:
  #
  # config :explorer, Explorer.Counters.TransactionCounter, subscribe_events: false
  defp subscribe_to_events do
    config = Application.get_env(:explorer, Explorer.Counters.TransactionCounter)

    case Keyword.get(config, :subscribe_events) do
      false -> nil
      _ -> Chain.subscribe_to_events(:transactions)
    end
  end

  @doc """
  Consolidates the number of transactions grouped by address.
  """
  def consolidate do
    total_transactions = Transaction.consolidate_by_address()

    for {address_hash, total} <- total_transactions do
      Address.TransactionCounter.insert_or_update_counter({address_hash, total})
    end
  end

  @impl true
  def handle_info({:chain_event, :transactions, _type, transaction_hashes}, state) do
    transaction_hashes
    |> Chain.hashes_to_transactions([])
    |> prepare_transactions
    |> Enum.each(&Address.TransactionCounter.insert_or_update_counter(&1))

    {:noreply, state}
  end

  def prepare_transactions(transactions) do
    transactions
    |> Enum.flat_map(&[&1.to_address_hash, &1.from_address_hash, &1.created_contract_address_hash])
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(& &1)
    |> Enum.map(fn {address_hash, hashes} -> {address_hash, Enum.count(hashes)} end)
  end
end
