# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.CreationDataResolver do
  @moduledoc """
  Discovers the creation data (creation bytecode, creating transaction, deployer)
  of a contract whose creation is not in the database yet.

  Contracts deployed by factories are created inside internal transactions,
  which are indexed asynchronously by `Indexer.Fetcher.InternalTransaction`
  after the block is imported. Deploy scripts usually request verification
  right after deployment, inside that window, so `Explorer.SmartContract.Helper.fetch_data_for_verification/3`
  would otherwise send the verification request without creation data.
  Chains without a tracing node never get internal transactions at all.

  The resolver is synchronous and runs inside the verification worker:

    1. Checks whether the contract already existed in block `0` (genesis).
    2. Finds the creation block by a binary search over `eth_getTransactionCount`
       (`Explorer.Chain.Fetcher.ContractCreationBlock`) and sanity-checks the result
       with `eth_getCode` at blocks `N-1` and `N`.
    3. Waits (bounded by `max_wait`) for the block to be imported, marking it as
       missing with the highest priority when it is not.
    4. Re-checks the database, since a top-level creation is imported with the block.
    5. Traces the block read-only with the same strategy the indexer uses and picks
       the successful `create`/`create2` trace that created the contract.
    6. Inserts a prioritized pending operation for the block so the indexer stores
       the internal transactions later.

  Every failure is mapped to an error tuple; the resolver never raises.
  """

  require Logger

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.FetchedCodes
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.{Block, Hash, PendingOperationsHelper, SmartContract, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Fetcher.ContractCreationBlock
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  @default_max_wait 20_000
  @default_poll_interval 2_000
  @nonce_retry_delay_ms 250
  # Change `1` to specific label when `priority` field becomes `Ecto.Enum`.
  @priority 1

  @type creation_data :: %{
          init: String.t(),
          block_number: non_neg_integer(),
          transaction_hash: String.t(),
          transaction_index: non_neg_integer(),
          from_address_hash: String.t()
        }

  @type error_reason ::
          :disabled
          | :creation_block_not_found
          | :block_not_indexed
          | :tracing_unavailable
          | :not_found_in_trace
          | :rpc_error

  @doc """
  Resolves the creation data of the contract at `address_hash`.

  Returns `{:error, :genesis}` when the contract already existed in block `0`
  and one of `t:error_reason/0` when the creation data cannot be discovered.
  """
  @spec resolve(Hash.Address.t() | binary()) :: {:ok, creation_data()} | {:error, :genesis | error_reason()}
  def resolve(address_hash) do
    address = address_hash |> to_string() |> String.downcase()

    if enabled?() do
      do_resolve(address)
    else
      {:error, :disabled}
    end
  rescue
    exception ->
      Logger.error(fn ->
        [
          "Failed to resolve creation data for #{address_hash}: ",
          Exception.format(:error, exception, __STACKTRACE__)
        ]
      end)

      {:error, :rpc_error}
  catch
    :exit, reason ->
      Logger.error("Failed to resolve creation data for #{address_hash}: #{inspect(reason)}")
      {:error, :rpc_error}
  end

  defp do_resolve(address) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    with :ok <- check_not_genesis(address, json_rpc_named_arguments),
         {:ok, block_number} <- find_creation_block(address, json_rpc_named_arguments),
         :ok <- sanity_check(address, block_number, json_rpc_named_arguments),
         :ok <- wait_for_block(block_number),
         {:db, nil} <- {:db, SmartContract.creation_transaction_with_bytecode(address)},
         :ok <- check_tracing_available(block_number),
         {:ok, traces} <- fetch_traces(block_number, json_rpc_named_arguments),
         {:ok, trace} <- pick_creating_trace(traces, address),
         :ok <- confirm_parent_transaction(trace) do
      persist_pending_operation(block_number)

      {:ok,
       %{
         init: trace.init,
         block_number: trace.block_number,
         transaction_hash: trace.transaction_hash,
         transaction_index: trace.transaction_index,
         from_address_hash: trace.from_address_hash
       }}
    else
      {:db, %{init: init, transaction: transaction}} ->
        {:ok,
         %{
           init: init,
           block_number: transaction.block_number,
           transaction_hash: to_string(transaction.hash),
           transaction_index: transaction.index,
           from_address_hash: to_string(transaction.from_address_hash)
         }}

      {:db, %{init: init, internal_transaction: internal_transaction}} ->
        {:ok,
         %{
           init: init,
           block_number: internal_transaction.block_number,
           transaction_hash: to_string(internal_transaction.transaction.hash),
           transaction_index: internal_transaction.transaction_index,
           from_address_hash: to_string(internal_transaction.from_address_hash)
         }}

      {:error, _} = error ->
        error
    end
  end

  # Contracts present in block 0 are genesis contracts and have no creation data.
  # An RPC error (for example a non-archive node) is ignored; the search continues.
  defp check_not_genesis(address, json_rpc_named_arguments) do
    case EthereumJSONRPC.fetch_codes([%{block_quantity: "0x0", address: address}], json_rpc_named_arguments) do
      {:ok, %FetchedCodes{params_list: [%{code: code}]}} ->
        if empty_code?(code), do: :ok, else: {:error, :genesis}

      _ ->
        :ok
    end
  end

  defp find_creation_block(address, json_rpc_named_arguments) do
    search_result =
      ContractCreationBlock.find(address,
        max_block_number: head_block_number(json_rpc_named_arguments),
        retry_delay_ms: @nonce_retry_delay_ms,
        json_rpc_named_arguments: json_rpc_named_arguments
      )

    case search_result do
      {:ok, 0} -> {:error, :genesis}
      {:ok, block_number} -> {:ok, block_number}
      {:error, _} -> {:error, :creation_block_not_found}
    end
  end

  # The DB head may be behind the creation block right after deployment, so the
  # node head is preferred as the right bound of the search.
  defp head_block_number(json_rpc_named_arguments) do
    case EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) do
      {:ok, number} when is_integer(number) -> number
      _ -> BlockNumber.get_max()
    end
  end

  # The nonce binary search converges on the right bound for contracts whose
  # nonce is 0 at every block (pre-Spurious-Dragon contracts, some predeploys).
  # The code must appear exactly between blocks N-1 and N.
  defp sanity_check(address, block_number, json_rpc_named_arguments) do
    params = [
      %{block_quantity: integer_to_quantity(block_number - 1), address: address},
      %{block_quantity: integer_to_quantity(block_number), address: address}
    ]

    case EthereumJSONRPC.fetch_codes(params, json_rpc_named_arguments) do
      {:ok, %FetchedCodes{params_list: [_, _] = params_list, errors: []}} ->
        code_by_block_number = Map.new(params_list, &{&1.block_number, &1.code})

        if empty_code?(code_by_block_number[block_number - 1]) and not empty_code?(code_by_block_number[block_number]) do
          :ok
        else
          {:error, :creation_block_not_found}
        end

      _ ->
        :ok
    end
  end

  defp wait_for_block(block_number) do
    if Block.indexed?(block_number) do
      :ok
    else
      MissingBlockRange.add_ranges_by_block_numbers([block_number], @priority)
      poll_block(block_number, max_wait())
    end
  end

  defp poll_block(_block_number, remaining) when remaining <= 0, do: {:error, :block_not_indexed}

  defp poll_block(block_number, remaining) do
    interval = min(poll_interval(), remaining)
    :timer.sleep(interval)

    if Block.indexed?(block_number) do
      :ok
    else
      poll_block(block_number, remaining - interval)
    end
  end

  defp check_tracing_available(block_number) do
    fetcher_disabled? =
      Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor)[:disabled?] == true

    if not fetcher_disabled? and RangesHelper.traceable_block_number?(block_number) do
      :ok
    else
      {:error, :tracing_unavailable}
    end
  end

  defp fetch_traces(block_number, json_rpc_named_arguments) do
    result =
      case PendingOperationsHelper.pending_operations_type() do
        "blocks" ->
          EthereumJSONRPC.fetch_block_internal_transactions([block_number], json_rpc_named_arguments)

        "transactions" ->
          block_number
          |> transactions_to_trace()
          |> fetch_transactions_traces(json_rpc_named_arguments)
      end

    case result do
      {:ok, traces} when is_list(traces) ->
        {:ok, traces}

      :ignore ->
        {:error, :tracing_unavailable}

      error ->
        Logger.warning("Failed to trace block #{block_number} for creation data discovery: #{inspect(error)}")
        {:error, :rpc_error}
    end
  end

  defp transactions_to_trace(block_number) do
    [block_number]
    |> Transaction.get_transactions_of_block_numbers()
    |> Transaction.filter_non_traceable_transactions()
    |> Enum.filter(&(&1.status == :ok))
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&%{block_number: &1.block_number, hash_data: to_string(&1.hash), transaction_index: &1.index})
  end

  defp fetch_transactions_traces([], _json_rpc_named_arguments), do: {:ok, []}

  defp fetch_transactions_traces(transactions_params, json_rpc_named_arguments) do
    EthereumJSONRPC.fetch_internal_transactions(transactions_params, json_rpc_named_arguments)
  end

  # The last creating trace in block order mirrors the `desc` ordering of
  # `Explorer.Chain.Address.creation_internal_transaction_query/1`.
  defp pick_creating_trace(traces, address) do
    traces
    |> Enum.filter(fn trace ->
      to_string(Map.get(trace, :type)) in ["create", "create2"] and
        is_nil(Map.get(trace, :error)) and
        downcase_or_nil(Map.get(trace, :created_contract_address_hash)) == address
    end)
    |> Enum.sort_by(&{&1.transaction_index, &1.index})
    |> List.last()
    |> case do
      nil -> {:error, :not_found_in_trace}
      trace -> {:ok, trace}
    end
  end

  # The block is indexed at this point, so the parent transaction is in the DB.
  defp confirm_parent_transaction(%{transaction_hash: transaction_hash_string}) do
    with {:ok, transaction_hash} <- Hash.Full.cast(transaction_hash_string),
         %Transaction{status: :ok} <- Repo.get(Transaction, transaction_hash) do
      :ok
    else
      _ -> {:error, :not_found_in_trace}
    end
  end

  defp confirm_parent_transaction(_trace), do: {:error, :not_found_in_trace}

  # Fire-and-forget: the pending operation makes the indexer store the internal
  # transactions of the block. On conflict only the priority is raised.
  defp persist_pending_operation(block_number) do
    PendingOperationsHelper.insert_pending_operations([block_number], @priority)
    :ok
  rescue
    exception ->
      Logger.error(fn ->
        [
          "Failed to insert pending operation for block #{block_number}: ",
          Exception.format(:error, exception, __STACKTRACE__)
        ]
      end)

      :ok
  end

  defp empty_code?(code), do: code in [nil, "", "0x"]

  defp downcase_or_nil(nil), do: nil
  defp downcase_or_nil(value), do: value |> to_string() |> String.downcase()

  defp config, do: Application.get_env(:explorer, __MODULE__, [])

  defp enabled?, do: Keyword.get(config(), :enabled, true)

  defp max_wait, do: Keyword.get(config(), :max_wait) || @default_max_wait

  defp poll_interval, do: Keyword.get(config(), :poll_interval) || @default_poll_interval
end
