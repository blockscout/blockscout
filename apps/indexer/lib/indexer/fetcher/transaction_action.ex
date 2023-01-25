defmodule Indexer.Fetcher.TransactionAction do
  @moduledoc """
  Fetches information about transaction actions.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Log, TransactionAction}
  alias Indexer.Transform.{Addresses, TransactionActions}

  defstruct first_block: nil, last_block: nil, protocols: [], task: nil, pid: nil

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, restart: :transient)
  end

  def start_link(arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    opts =
      Application.get_all_env(:indexer)[__MODULE__]
      |> Keyword.merge(opts)

    first_block = Keyword.get(opts, :reindex_first_block)
    last_block = Keyword.get(opts, :reindex_last_block)

    cond do
      !is_nil(first_block) and !is_nil(last_block) ->
        init_fetching(opts, first_block, last_block)

      is_nil(first_block) and !is_nil(last_block) ->
        {:stop, "Please, specify the first block of the block range for #{__MODULE__}."}

      !is_nil(first_block) and is_nil(last_block) ->
        {:stop, "Please, specify the last block of the block range for #{__MODULE__}."}

      true ->
        :ignore
    end
  end

  @impl GenServer
  def handle_info(:fetch, %__MODULE__{} = state) do
    task = Task.Supervisor.async_nolink(Indexer.Fetcher.TransactionAction.TaskSupervisor, fn -> task(state) end)
    {:noreply, %__MODULE__{state | task: task}}
  end

  def handle_info(:stop_server, %__MODULE__{} = state) do
    :ets.delete(:tx_actions_last_block_processed)
    {:stop, :normal, state}
  end

  def handle_info({ref, _result}, %__MODULE__{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, %__MODULE__{state | task: nil}}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{task: %Task{pid: pid, ref: ref}} = state
      ) do
    if reason === :normal do
      {:noreply, %__MODULE__{state | task: nil}}
    else
      Logger.metadata(fetcher: :transaction_action)
      Logger.error(fn -> "Transaction action fetcher task exited due to #{inspect(reason)}. Rerunning..." end)
      {:noreply, run_fetch(state)}
    end
  end

  defp run_fetch(state) do
    pid = self()
    Process.send(pid, :fetch, [])
    %__MODULE__{state | task: nil, pid: pid}
  end

  defp task(%__MODULE__{first_block: first_block, last_block: last_block_init, protocols: protocols, pid: pid} = _state) do
    Logger.metadata(fetcher: :transaction_action)

    last_block =
      with info when info != :undefined <- :ets.info(:tx_actions_last_block_processed),
           [{_, block_number}] <- :ets.lookup(:tx_actions_last_block_processed, :block_number) do
        block_number - 1
      else
        _ -> last_block_init
      end

    block_range = Range.new(last_block, first_block, -1)
    block_range_init_length = last_block_init - first_block + 1

    for block_number <- block_range do
      query =
        from(
          log in Log,
          where: log.block_number == ^block_number,
          select: log
        )

      %{transaction_actions: transaction_actions} =
        query
        |> Repo.all()
        |> TransactionActions.parse(protocols)

      addresses =
        Addresses.extract_addresses(%{
          transaction_actions: transaction_actions
        })

      tx_actions =
        Enum.map(transaction_actions, fn action ->
          Map.put(action, :data, Map.delete(action.data, :block_number))
        end)

      {:ok, _} =
        Chain.import(%{
          addresses: %{params: addresses, on_conflict: :nothing},
          transaction_actions: %{params: tx_actions},
          timeout: :infinity
        })

      blocks_processed = last_block_init - block_number + 1

      progress_percentage =
        blocks_processed
        |> Decimal.div(block_range_init_length)
        |> Decimal.mult(100)
        |> Decimal.round(2)
        |> Decimal.to_string()

      Logger.info(
        "Block #{block_number} handled successfully. Progress: #{progress_percentage}%. Initial block range: #{first_block}..#{last_block_init}." <>
          if(block_number > first_block, do: " Remaining block range: #{first_block}..#{block_number - 1}", else: "")
      )

      :ets.insert(:tx_actions_last_block_processed, {:block_number, block_number})
    end

    Process.send(pid, :stop_server, [])

    :ok
  end

  defp init_fetching(opts, first_block, last_block) do
    Logger.metadata(fetcher: :transaction_action)

    first_block = parse_integer(first_block)
    last_block = parse_integer(last_block)

    cond do
      is_nil(first_block) or is_nil(last_block) or first_block <= 0 or last_block <= 0 or first_block > last_block ->
        {:stop, "Correct block range must be provided to #{__MODULE__}."}

      last_block > (max_block_number = Chain.fetch_max_block_number()) ->
        {:stop,
         "The last block number (#{last_block}) provided to #{__MODULE__} is incorrect as it exceeds max block number available in DB (#{max_block_number})."}

      true ->
        supported_protocols =
          TransactionAction.supported_protocols()
          |> Enum.map(&Atom.to_string(&1))

        protocols =
          opts
          |> Keyword.get(:reindex_protocols, "")
          |> String.trim()
          |> String.split(",")
          |> Enum.map(&String.trim(&1))
          |> Enum.filter(&Enum.member?(supported_protocols, &1))

        Logger.info(
          "Running #{__MODULE__} for the block range #{first_block}..#{last_block} and " <>
            if(Enum.empty?(protocols),
              do: "all protocols.",
              else: "the following protocols: #{Enum.join(protocols, ", ")}."
            )
        )

        init_last_block_processed()

        state =
          %__MODULE__{
            first_block: first_block,
            last_block: last_block,
            protocols: protocols
          }
          |> run_fetch()

        {:ok, state}
    end
  end

  defp init_last_block_processed do
    if :ets.whereis(:tx_actions_last_block_processed) == :undefined do
      :ets.new(:tx_actions_last_block_processed, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  end

  defp parse_integer(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
end
