defmodule Indexer.Code.Fetcher do
  @moduledoc """
  Fetches `contract_code` `t:Explorer.Chain.Address.t/0`.
  """

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
        [:block_number, :created_contract_address_hash, :hash],
        initial,
        fn transaction_fields, acc ->
          transaction_fields
          |> entry()
          |> reducer.(acc)
        end
      )

    final
  end

  defp entry(%{
         block_number: block_number,
         created_contract_address_hash: %Hash{bytes: created_contract_bytes},
         hash: %Hash{bytes: bytes}
       })
       when is_integer(block_number) do
    {block_number, created_contract_bytes, bytes}
  end

  defp params({block_number, created_contract_address_hash_bytes, transaction_hash_bytes})
       when is_integer(block_number) do
    {:ok, transaction_hash} = Hash.Full.cast(transaction_hash_bytes)
    {:ok, created_contract_address_hash} = Hash.Full.cast(created_contract_address_hash_bytes)

    %{block_quantity: block_number, address: created_contract_address_hash, transaction_hash: transaction_hash}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Code.Fetcher.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, json_rpc_named_arguments) do
    Logger.debug("fetching created_contract_code for transactions")

    entries
    |> Enum.map(&params/1)
    |> EthereumJSONRPC.fetch_codes(json_rpc_named_arguments)
    |> case do
      {:ok, create_address_codes} ->
        addresses_params = AddressExtraction.extract_addresses(%{codes: create_address_codes.params_list})

        address_hash_to_block_number =
          Enum.into(addresses_params, %{}, fn %{fetched_coin_balance_block_number: block_number, hash: address} ->
            {address, block_number}
          end)

        transaction_params = transaction_params(entries, addresses_params)

        with {:ok, imported} <-
               Chain.import(%{
                 addresses: %{params: addresses_params},
                 transactions: %{params: transaction_params},
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
                  "failed to import created_contract_code for transactions: ",
                  inspect(reason)
                ]
              end,
              step: step
            )

            {:retry, entries}
        end
    end
  end

  defp transaction_params(entries, addresses_params) do
    entries
    |> Enum.filter(fn %{address: created_contract_address_hash} ->
      Enum.any?(addresses_params, fn %{hash: hash} ->
        hash == created_contract_address_hash
      end)
    end)
    |> Enum.map(fn %{address: created_contract_address_hash, transaction_hash: transaction_hash} ->
      %{
        created_contract_address_hash: created_contract_address_hash,
        hash: transaction_hash,
        created_contract_code_indexed_at: DateTime.utc_now()
      }
    end)
  end
end
