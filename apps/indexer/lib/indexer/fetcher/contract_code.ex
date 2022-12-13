defmodule Indexer.Fetcher.ContractCode do
  @moduledoc """
  Fetches `contract_code` `t:Explorer.Chain.Address.t/0`.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Cache.Accounts
  alias Indexer.{BufferedTask, Tracer}
  # alias Indexer.Fetcher.CoinBalance, as: CoinBalanceFetcher
  alias Indexer.Transform.Addresses

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.ContractCode.TaskSupervisor,
    metadata: [fetcher: :code]
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

  defp params({block_number, created_contract_address_hash_bytes, _transaction_hash_bytes})
       when is_integer(block_number) do
    {:ok, created_contract_address_hash} = Hash.Address.cast(created_contract_address_hash_bytes)

    %{block_quantity: integer_to_quantity(block_number), address: to_string(created_contract_address_hash)}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.ContractCode.run/2",
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
        addresses_params = Addresses.extract_addresses(%{codes: create_address_codes.params_list})

        import_with_balances(addresses_params, entries, json_rpc_named_arguments)

      {:error, reason} ->
        Logger.error(fn -> ["failed to fetch contract codes: ", inspect(reason)] end,
          error_count: Enum.count(entries)
        )

        {:retry, entries}
    end
  end

  # todo: return
  defp import_with_balances(addresses_params, entries, _json_rpc_named_arguments) do
    case Chain.import(%{
           addresses: %{params: addresses_params, on_conflict: :update_contract_code},
           timeout: :infinity
         }) do
      {:ok, imported} ->
        Accounts.drop(imported[:addresses])
        :ok

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

    # entries
    # |> coin_balances_request_params()
    # |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments)
    # |> case do
    #   {:ok, fetched_balances} ->
    #     # balance_addresses_params = CoinBalanceFetcher.balances_params_to_address_params(fetched_balances.params_list)

    #     # merged_addresses_params = Addresses.merge_addresses(addresses_params ++ balance_addresses_params)

    #     case Chain.import(%{
    #            addresses: %{params: addresses_params},
    #            timeout: :infinity
    #          }) do
    #       {:ok, imported} ->
    #         Accounts.drop(imported[:addresses])
    #         :ok

    #       {:error, step, reason, _changes_so_far} ->
    #         Logger.error(
    #           fn ->
    #             [
    #               "failed to import created_contract_code for transactions: ",
    #               inspect(reason)
    #             ]
    #           end,
    #           step: step
    #         )

    #         {:retry, entries}
    #     end

    #   {:error, reason} ->
    #     Logger.error(fn -> ["failed to fetch contract codes: ", inspect(reason)] end,
    #       error_count: Enum.count(entries)
    #     )

    #     {:retry, entries}
    # end
  end

  # defp coin_balances_request_params(entries) do
  #   Enum.map(entries, fn {block_number, created_contract_address_hash_bytes, _transaction_hash_bytes} ->
  #     {:ok, created_contract_address_hash} = Hash.Address.cast(created_contract_address_hash_bytes)

  #     %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(created_contract_address_hash)}
  #   end)
  # end
end
