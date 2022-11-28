defmodule Indexer.Fetcher.TransactionAction do
  @moduledoc """
  Fetches information about a transaction action.
  """

  require Logger

  use Indexer.Fetcher
  use Spandex.Decorators

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Log, TransactionActions}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Transform.{Addresses, TransactionActions}

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    task_supervisor: Indexer.Fetcher.TransactionAction.TaskSupervisor
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, _reducer, _) do
    first_block = Application.get_env(:indexer, :tx_actions_reindex_first_block)
    last_block = Application.get_env(:indexer, :tx_actions_reindex_last_block)

    cond do
      !is_nil(first_block) and !is_nil(last_block) ->
        first_block = parse_integer(first_block)
        last_block = parse_integer(last_block)

        if is_nil(first_block) or is_nil(last_block) or first_block < 0 or last_block < 0 or first_block > last_block do
          raise ArgumentError, "Correct block range must be provided to `#{__MODULE__}.init`"
        end

        supported_protocols =
          Explorer.Chain.TransactionActions.supported_protocols()
          |> Enum.map(&Atom.to_string(&1))

        protocols =
          :indexer
          |> Application.get_env(:tx_actions_reindex_protocols, "")
          |> String.trim()
          |> String.split(",")
          |> Enum.map(&String.trim(&1))
          |> Enum.filter(&Enum.member?(supported_protocols, &1))

        Logger.info(
          "Calling `#{__MODULE__}.init` for the block range #{first_block}...#{last_block} and " <>
            if(Enum.empty?(protocols),
              do: "all protocols",
              else: "the following protocols: #{Enum.join(protocols, ", ")}"
            )
        )

        first_block
        |> Range.new(last_block, -1)
        |> Enum.each(fn block_number ->
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

          transaction_actions =
            Enum.map(transaction_actions, fn action ->
              Map.put(action, :data, Map.delete(action.data, :block_number))
            end)

          {:ok, _} =
            Chain.import(%{
              addresses: %{params: addresses},
              transaction_actions: %{params: transaction_actions},
              timeout: :infinity
            })
        end)

      is_nil(first_block) and !is_nil(last_block) ->
        Logger.warn("Please, specify the first block of the block range for #{__MODULE__}.init")

      !is_nil(first_block) and is_nil(last_block) ->
        Logger.warn("Please, specify the last block of the block range for #{__MODULE__}.init")

      true ->
        nil
    end

    initial_acc
  end

  @impl BufferedTask
  @decorate trace(name: "fetch", resource: "Indexer.Fetcher.TransactionAction.run/2", service: :indexer, tracer: Tracer)
  def run(_, _json_rpc_named_arguments) do
    :ok
  end

  defp parse_integer(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
end
