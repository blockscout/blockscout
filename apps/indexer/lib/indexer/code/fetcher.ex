defmodule Indexer.Code.Fetcher do
  use Spandex.Decorators

  require Logger

  import Indexer.Block.Fetcher, only: [async_import_coin_balances: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Indexer.{AddressExtraction, BufferedTask, Tracer}

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Code.TaskSupervisor,
    metadata: [fetcher: :internal_transaction]
  ]

  @spec async_fetch([%{required(:block_number) => Block.block_number(), required(:hash) => Hash.Full.t()}]) :: :ok
  def async_fetch(transactions_fields, timeout \\ 5000) when is_list(transactions_fields) do
    entries = Enum.map(transactions_fields, &entry/1)

    BufferedTask.buffer(__MODULE__, entries, timeout)
  end

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
  def init(initial, reducer, _) do
    {:ok, final} =
      Chain.stream_transactions_with_unfetched_created_contract_codes(
        [:block_number, :hash],
        initial,
        fn transaction_fields, acc ->
          transaction_fields
          |> entry()
          |> reducer.(acc)
        end
      )

    final
  end

  defp entry(%{block_number: block_number, hash: %Hash{bytes: bytes}}) when is_integer(block_number) do
    {block_number, bytes}
  end

  defp params({block_number, _hash_bytes, created_contract_address_hash}) when is_integer(block_number) do
    %{block_quantity: block_number, address: created_contract_address_hash}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Code.Fetcher.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, json_rpc_named_arguments) do
    Logger.debug("fetching internal transactions for transactions")

    entries
    |> Enum.map(&params/1)
    |> EthereumJSONRPC.fetch_codes(json_rpc_named_arguments)
    |> case do
      {:ok, create_address_codes} ->
        addresses_params = AddressExtraction.extract_addresses(%{codes: create_address_codes})

        address_hash_to_block_number =
          Enum.into(addresses_params, %{}, fn %{block_number: block_number, address: address} ->
            {address, block_number}
          end)

        with {:ok, imported} <-
               Chain.import(%{
                 addresses: %{params: addresses_params},
                 timeout: :infinity
               }) do
          async_import_coin_balances(imported, %{
            address_hash_to_fetched_balance_block_number: address_hash_to_block_number
          })
        else
          {:error, step, reason, _changes_so_far} ->
            Logger.error(
              fn ->
                [
                  "failed to import internal transactions for transactions: ",
                  inspect(reason)
                ]
              end,
              step: step
            )

            {:retry, entries}
        end

      {:error, reason} ->
        Logger.error(fn -> ["failed to fetch internal transactions for transactions: ", inspect(reason)] end)

        {:retry, entries}

      :ignore ->
        :ok
    end
  end
end
