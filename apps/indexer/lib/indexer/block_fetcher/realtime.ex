defmodule Indexer.BlockFetcher.Realtime do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward.
  """

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Indexer.BlockFetcher, only: [stream_import: 1]

  alias Explorer.Chain
  alias Indexer.{AddressExtraction, BlockFetcher, Sequence}

  @behaviour BlockFetcher

  @enforce_keys ~w(block_fetcher interval)a
  defstruct block_fetcher: nil,
            interval: nil,
            task_by_ref: %{}

  def new(%{block_fetcher: %BlockFetcher{} = common_block_fetcher, block_interval: block_interval}) do
    block_fetcher = %BlockFetcher{
      common_block_fetcher
      | callback_module: __MODULE__,
        blocks_concurrency: 1,
        broadcast: true
    }

    interval = div(block_interval, 2)

    %__MODULE__{block_fetcher: block_fetcher, interval: interval}
  end

  @doc """
  Starts `task/1` and puts it in `t:Indexer.BlockFetcher.t/0` `realtime_task_by_ref`.
  """
  def put(%BlockFetcher.Supervisor{realtime: %__MODULE__{} = state} = supervisor_state) do
    %Task{ref: ref} = task = Task.Supervisor.async_nolink(Indexer.TaskSupervisor, __MODULE__, :task, [state])

    put_in(supervisor_state.realtime.task_by_ref[ref], task)
  end

  def task(%__MODULE__{block_fetcher: %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher}) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
    {:ok, sequence} = Sequence.start_link(first: latest_block_number, step: 2)
    stream_import(%BlockFetcher{block_fetcher | sequence: sequence})
  end

  @import_options ~w(address_hash_to_fetched_balance_block_number transaction_hash_to_block_number)a

  @impl BlockFetcher
  def import(
        block_fetcher,
        %{
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number,
          addresses: %{params: addresses_params},
          transactions: %{params: transactions_params}
        } = options
      ) do
    with {:ok,
          %{
            addresses_params: internal_transactions_addresses_params,
            internal_transactions_params: internal_transactions_params
          }} <-
           internal_transactions(block_fetcher, %{
             addresses_params: addresses_params,
             transactions_params: transactions_params
           }),
         {:ok, %{addresses_params: balances_addresses_params, balances_params: balances_params}} <-
           balances(block_fetcher, %{
             address_hash_to_block_number: address_hash_to_block_number,
             address_params: internal_transactions_addresses_params
           }) do
      options
      |> Map.drop(@import_options)
      |> put_in([:addresses, :params], balances_addresses_params)
      |> put_in([Access.key(:balances, %{}), :params], balances_params)
      |> put_in([Access.key(:internal_transactions, %{}), :params], internal_transactions_params)
      |> Chain.import()
    end
  end

  def internal_transactions(
        %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments},
        %{addresses_params: addresses_params, transactions_params: transactions_params}
      ) do
    with {:ok, internal_transactions_params} <-
           transactions_params
           |> transactions_params_to_fetch_internal_transactions_params()
           |> EthereumJSONRPC.fetch_internal_transactions(json_rpc_named_arguments) do
      merged_addresses_params =
        %{internal_transactions: internal_transactions_params}
        |> AddressExtraction.extract_addresses()
        |> Kernel.++(addresses_params)
        |> AddressExtraction.merge_addresses()

      {:ok, %{addresses_params: merged_addresses_params, internal_transactions_params: internal_transactions_params}}
    end
  end

  defp transactions_params_to_fetch_internal_transactions_params(transactions_params) do
    Enum.map(transactions_params, &transaction_params_to_fetch_internal_transaction_params/1)
  end

  defp transaction_params_to_fetch_internal_transaction_params(%{block_number: block_number, hash: hash})
       when is_integer(block_number) do
    %{block_number: block_number, hash_data: to_string(hash)}
  end

  def balances(
        %BlockFetcher{json_rpc_named_arguments: json_rpc_named_arguments},
        %{
          address_params: address_params,
          address_hash_to_block_number: address_hash_to_block_number
        }
      ) do
    balances_params =
      Enum.map(address_params, fn %{hash: address_hash} = address_params when is_binary(address_hash) ->
        block_number =
          case address_params do
            %{fetched_balance_block_number: block_number} when is_integer(block_number) ->
              block_number

            _ ->
              Map.fetch!(address_hash_to_block_number, address_hash)
          end

        %{hash_data: address_hash, block_quantity: integer_to_quantity(block_number)}
      end)

    with {:ok, balances_params} <- EthereumJSONRPC.fetch_balances(balances_params, json_rpc_named_arguments) do
      merged_addresses_params =
        %{balances: balances_params}
        |> AddressExtraction.extract_addresses()
        |> Kernel.++(address_params)
        |> AddressExtraction.merge_addresses()

      {:ok, %{addresses_params: merged_addresses_params, balances_params: balances_params}}
    end
  end

  def handle_success(
        {ref, :ok = result},
        %BlockFetcher.Supervisor{realtime: %__MODULE__{task_by_ref: task_by_ref}} = supervisor_state
      ) do
    {task, running_task_by_ref} = Map.pop(task_by_ref, ref)

    case task do
      nil ->
        Logger.error(fn ->
          "Unknown ref (#{inspect(ref)}) that is neither the catchup index" <>
            " nor a realtime index Task ref returned result (#{inspect(result)})"
        end)

      _ ->
        :ok
    end

    Process.demonitor(ref, [:flush])

    put_in(supervisor_state.realtime.task_by_ref, running_task_by_ref)
  end

  def handle_failure(
        {:DOWN, ref, :process, pid, reason},
        %BlockFetcher.Supervisor{realtime: %__MODULE__{task_by_ref: task_by_ref}} = supervisor_state
      ) do
    {task, running_task_by_ref} = Map.pop(task_by_ref, ref)

    case task do
      nil ->
        Logger.error(fn ->
          "Unknown ref (#{inspect(ref)}) that is neither the catchup index" <>
            " nor a realtime index Task ref reports unknown pid (#{pid}) DOWN due to reason (#{reason}})"
        end)

      _ ->
        Logger.error(fn ->
          "Realtime index stream exited with reason (#{inspect(reason)}).  " <>
            "The next realtime index task will fill the missing block " <>
            "if the lastest block number has not advanced by then or the catch up index will fill the missing block."
        end)
    end

    put_in(supervisor_state.realtime.task_by_ref, running_task_by_ref)
  end
end
