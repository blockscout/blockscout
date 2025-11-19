defmodule Indexer.Fetcher.Optimism.OperatorFee do
  @moduledoc """
  Retrieves and saves operator fee for historic transactions from their receipts using RPC calls
  starting from the timestamp defined in INDEXER_OPTIMISM_L2_ISTHMUS_TIMESTAMP env variable.

  If the env variable is not defined or the chain type is not :optimism, the module doesn't start.

  Once the historic transactions are handled, the module stops working and doesn't start again
  after instance restarts. If there is a need to make it work again, the corresponding constant
  should be manually removed from the `constants` database table.

  The transaction queue handling is adjusted by `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_*` env variables.
  """

  require Logger

  use Indexer.Fetcher, restart: :transient
  use Spandex.Decorators

  import Ecto.Query

  import EthereumJSONRPC,
    only: [
      json_rpc: 2
    ]

  alias EthereumJSONRPC.Receipt
  alias EthereumJSONRPC.Receipts.ByTransactionHash
  alias Explorer.Application.Constants
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Repo

  alias Indexer.{BufferedTask, Helper}

  @behaviour BufferedTask

  @default_max_batch_size 100
  @default_max_concurrency 3
  @fetcher_name :optimism_operator_fee
  @fetcher_finished_constant_key "optimism_operator_fee_fetcher_finished"

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    if !state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    if Constants.get_constant_value(@fetcher_finished_constant_key) == "true" do
      Logger.info("All known transactions are previously handled by #{__MODULE__} module so it won't be started.",
        fetcher: @fetcher_name
      )

      Process.send(__MODULE__, :shutdown, [])
      initial_acc
    else
      isthmus_timestamp_l2 = Application.get_env(:indexer, Indexer.Fetcher.Optimism)[:isthmus_timestamp_l2]

      {:ok, acc} =
        Transaction.stream_transactions_without_operator_fee(
          initial_acc,
          fn data, acc ->
            Helper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
          end,
          isthmus_timestamp_l2
        )

      {transactions_count, _} = acc

      if transactions_count == 0 do
        Logger.info("All known transactions are handled by #{__MODULE__} module so it will be stopped.",
          fetcher: @fetcher_name
        )

        Constants.set_constant_value(@fetcher_finished_constant_key, "true")
        Process.send(__MODULE__, :shutdown, [])
      end

      acc
    end
  end

  @impl BufferedTask
  def run(hashes, json_rpc_named_arguments) when is_list(hashes) do
    Logger.metadata(fetcher: @fetcher_name)

    requests =
      hashes
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        ByTransactionHash.request(id, Hash.to_string(hash))
      end)

    error_message = &"eth_getTransactionReceipt failed. Error: #{inspect(&1)}"

    {:ok, receipts} =
      Helper.repeated_call(
        &json_rpc/2,
        [requests, json_rpc_named_arguments],
        error_message,
        Helper.infinite_retries_number()
      )

    receipts
    |> Enum.map(& &1.result)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Receipt.to_elixir/1)
    |> Enum.map(&Receipt.elixir_to_params/1)
    |> Enum.each(fn receipt ->
      now = DateTime.utc_now()

      Repo.update_all(
        from(t in Transaction, where: t.hash == ^receipt.transaction_hash),
        set: [
          operator_fee_scalar: receipt.operator_fee_scalar,
          operator_fee_constant: receipt.operator_fee_constant,
          updated_at: now
        ]
      )
    end)
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
