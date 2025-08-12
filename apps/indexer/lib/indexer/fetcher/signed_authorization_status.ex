defmodule Indexer.Fetcher.SignedAuthorizationStatus do
  @moduledoc """
  Fetches `status` `t:Explorer.Chain.SignedAuthorization.t/0`.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  require Logger

  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  import Explorer.Chain.SignedAuthorization.Reader,
    only: [
      stream_blocks_to_refetch_signed_authorizations_statuses: 2,
      address_hashes_to_latest_authorizations: 1
    ]

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Block, BlockNumberHelper, Hash, SignedAuthorization, Transaction}
  alias Explorer.Chain.Cache.Accounts
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Indexer.{BufferedTask, Tracer}

  @failed_to_import "failed to import signed_authorization status for transactions: "

  @type inner_entry ::
          {:transaction, %{authority: Hash.Address.t(), nonce: non_neg_integer()}}
          | {:authorization, SignedAuthorization.t()}

  @typedoc """
  Each entry is a list of all transactions and signed authorizations from the same block.

    - `:block_number` - The block number of given batch.
    - `:block_hash` - The block hash of given batch.
    - `:entries` - The signed authorizations merged with transaction nonces.
  """
  @type entry :: %{
          required(:block_number) => Block.block_number(),
          required(:block_hash) => Hash.Full.t(),
          optional(:entries) => [inner_entry()]
        }

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 1

  @doc """
  Enqueues a batch of transactions to fetch and handle signed authorization statuses.
  Only works correctly if all transactions and signed authorizations from the particular block
  are present in the list at the same time.
  """
  @spec async_fetch([Transaction.t()], [SignedAuthorization.t()], boolean(), integer()) :: :ok
  def async_fetch(
        transactions,
        signed_authorizations,
        realtime?,
        timeout \\ 5000
      ) do
    grouped_signed_authorizations = signed_authorizations |> Enum.group_by(& &1.transaction_hash)

    BufferedTask.buffer(
      __MODULE__,
      transactions
      |> RangesHelper.filter_traceable_block_numbers()
      |> Enum.map(&Map.put(&1, :signed_authorizations, Map.get(grouped_signed_authorizations, &1.hash, [])))
      |> entries_from_transactions(),
      realtime?,
      timeout
    )
  end

  # Chunks a list of transactions into entries, with all transactions from the same block grouped together.
  @spec entries_from_transactions([Transaction.t()]) :: [entry()]
  defp entries_from_transactions(transactions) do
    transactions
    |> Enum.group_by(& &1.block_hash)
    |> Enum.map(fn {block_hash, block_transactions} ->
      %{
        block_number: block_transactions |> List.first() |> Map.get(:block_number),
        block_hash: block_hash,
        entries:
          block_transactions
          |> Enum.sort_by(& &1.index)
          |> Enum.flat_map(&transaction_to_inner_entries/1)
      }
    end)
    |> Enum.sort_by(& &1.block_number)
  end

  # Extract all nonce changes from transaction with signed authorizations.
  #
  # Any transaction change the nonce of the transaction sender.
  #
  # Additionally, EIP7702 transactions may change the nonce of successful EIP7702 tuple authorities.
  @spec transaction_to_inner_entries(Transaction.t()) :: [inner_entry()]
  defp transaction_to_inner_entries(transaction) do
    [
      {:transaction, %{authority: transaction.from_address_hash, nonce: transaction.nonce}}
      | transaction
        |> Map.get(:signed_authorizations, [])
        |> Enum.sort_by(& &1.index)
        |> Enum.map(&{:authorization, &1})
    ]
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
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    stream_reducer = RangesHelper.stream_reducer_traceable(reducer)

    # here we stream only block hashes, transactions are preloaded later by `preload_entries/1`
    {:ok, final} =
      stream_blocks_to_refetch_signed_authorizations_statuses(
        initial,
        stream_reducer
      )

    final
  end

  @doc """
  Processes a batch of entries to fetch and handle signed authorization statuses.
  This function is executed as part of the `BufferedTask` behavior.

  ## Parameters

    - `entries`: A list of entries to process.
    - `json_rpc_named_arguments`: A list of options for JSON-RPC communication.

  ## Returns

    - `:ok`: Indicates successful processing of the signed authorization statuses.
    - `{:retry, any()}`: Returns the entries for retry if an error occurs during
      the fetch operation.
  """
  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.SignedAuthorizationStatus.run/2",
              service: :indexer,
              tracer: Tracer
            )
  @spec run([entry()], [
          {:throttle_timeout, non_neg_integer()}
          | {:transport, atom()}
          | {:transport_options, any()}
          | {:variant, atom()}
        ]) :: :ok | {:retry, any()}
  def run(entries, json_rpc_named_arguments) do
    Logger.debug("fetching signed authorization statuses")

    # preload transactions for init-generated entries, in case of retry, preloaded transactions are preserved
    entries = entries |> Enum.map(&preload_entries/1)

    # compute pairs of block numbers and addresses for which don't know nonce at the start of the block
    missing_nonces_for = entries |> Enum.flat_map(&compute_missing_nonces/1)

    with {:fetch, {:ok, nonces_map}} <- {:fetch, fetch_nonces(missing_nonces_for, json_rpc_named_arguments)},
         {new_entries, updated_authorizations} =
           entries
           |> Enum.map(&compute_statuses(&1, Map.get(nonces_map, &1.block_number, %{})))
           |> Enum.unzip(),
         {:import, :ok} <- {:import, import_authorizations(List.flatten(updated_authorizations))} do
      entries_to_retry =
        new_entries
        |> Enum.filter(
          &Enum.any?(&1, fn
            {:authorization, %{status: nil}} -> true
            _ -> false
          end)
        )

      if Enum.empty?(entries_to_retry) do
        :ok
      else
        {:retry, entries_to_retry}
      end
    else
      {:fetch, {:error, reason}} ->
        Logger.error(fn -> ["failed to fetch address nonces: ", inspect(reason)] end,
          error_count: Enum.count(missing_nonces_for)
        )

        {:retry, entries}

      {:import, {:error, reason}} ->
        Logger.error(fn -> ["failed to import signed authorizations: ", inspect(reason)] end)

        {:retry, entries}
    end
  end

  @spec preload_entries(entry()) :: entry()
  defp preload_entries(%{entries: entries} = entry) when not is_nil(entries) do
    entry
  end

  defp preload_entries(%{block_hash: block_hash} = entry) do
    block =
      block_hash
      |> Chain.fetch_block_by_hash()
      |> Repo.preload([:transactions, [transactions: :signed_authorizations]])

    entry
    |> Map.put(
      :entries,
      block
      |> Map.get(:transactions, [])
      |> Enum.sort_by(& &1.index)
      |> Enum.flat_map(&transaction_to_inner_entries/1)
    )
  end

  # Compute pairs of block numbers and addresses for which don't know nonce at the start of the block.
  #
  # Checks all authorizations signers and returns those without any prior transactions with known nonce.
  @spec compute_missing_nonces(entry()) :: [%{block_number: Block.block_number(), address_hash: Hash.Address.t()}]
  defp compute_missing_nonces(%{block_number: block_number, entries: entries}) do
    entries
    |> Enum.reduce({[], MapSet.new()}, fn element, {missing_nonces, known_nonces} ->
      case element do
        # once we have seen a transaction in the block, we can be certain in address nonce for later transactions in the same block
        {:transaction, %{authority: authority}} ->
          {missing_nonces, known_nonces |> MapSet.put(authority)}

        {:authorization, %{authority: authority, status: nil}} when not is_nil(authority) ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if MapSet.member?(known_nonces, authority) do
            {missing_nonces, known_nonces}
          else
            {[%{block_number: block_number, address_hash: authority} | missing_nonces],
             known_nonces |> MapSet.put(authority)}
          end

        _ ->
          {missing_nonces, known_nonces}
      end
    end)
    |> elem(0)
  end

  # Compute authorization statuses by iteratively going through all transactions and authorizations in the block,
  # while keeping track of expected nonces.
  @spec compute_statuses(entry(), %{Hash.Address.t() => non_neg_integer()}) :: {entry(), [SignedAuthorization.t()]}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp compute_statuses(entry, known_nonces) do
    {new_entries, {updated_authorizations, _}} =
      entry.entries
      |> Enum.map_reduce({[], known_nonces}, fn
        {:transaction, transaction} = entry, {updated_authorizations, known_nonces} ->
          {entry, {updated_authorizations, known_nonces |> Map.put(transaction.authority, transaction.nonce + 1)}}

        {:authorization, authorization} = entry, {updated_authorizations, known_nonces} ->
          nonce = Decimal.to_integer(authorization.nonce)
          status = SignedAuthorization.basic_validate(authorization)

          cond do
            # if authorization is valid, update known nonce and proceed
            authorization.status == :ok ->
              {entry, {updated_authorizations, known_nonces |> Map.put(authorization.authority, nonce + 1)}}

            # if authorization is invalid, nonce is not incremented
            authorization.status in [:invalid_signature, :invalid_chain_id, :invalid_nonce] ->
              {entry, {updated_authorizations, known_nonces}}

            # remaining cases handle authorization.status == nil

            status in [:invalid_signature, :invalid_chain_id, :invalid_nonce] ->
              new_authorization = %{authorization | status: status}

              {{:authorization, new_authorization}, {[new_authorization | updated_authorizations], known_nonces}}

            # we still can't get chain_id from the json rpc, so we can't validate authorization and don't know up-to-date nonce anymore
            is_nil(status) ->
              {entry, {updated_authorizations, known_nonces |> Map.delete(authorization.authority)}}

            Map.has_key?(known_nonces, authorization.authority) and
                nonce != Map.get(known_nonces, authorization.authority) ->
              new_authorization = %{authorization | status: :invalid_nonce}

              {{:authorization, new_authorization}, {[new_authorization | updated_authorizations], known_nonces}}

            Map.has_key?(known_nonces, authorization.authority) and
                nonce == Map.get(known_nonces, authorization.authority) ->
              new_authorization = %{authorization | status: :ok}

              {
                {:authorization, new_authorization},
                {[new_authorization | updated_authorizations],
                 known_nonces |> Map.put(authorization.authority, nonce + 1)}
              }

            true ->
              # we couldn't validate authorization due to unknown nonce, we don't know up-to-date nonce anymore
              {entry, {updated_authorizations, known_nonces |> Map.delete(authorization.authority)}}
          end
      end)

    {entry |> Map.put(:entries, new_entries), updated_authorizations |> Enum.reverse()}
  end

  @spec fetch_nonces([%{block_number: Block.block_number(), address_hash: Hash.Address.t()}], keyword()) ::
          {:ok, %{Block.block_number() => %{Hash.Address.t() => non_neg_integer()}}} | {:error, any()}
  defp fetch_nonces([], _json_rpc_named_arguments), do: {:ok, %{}}

  defp fetch_nonces(entries, json_rpc_named_arguments) do
    # fetch nonces for at the end of the previous block, to know starting nonces for the current block
    entries
    |> Enum.map(
      &%{
        block_quantity: integer_to_quantity(BlockNumberHelper.previous_block_number(&1.block_number)),
        address: to_string(&1.address_hash)
      }
    )
    |> EthereumJSONRPC.fetch_nonces(json_rpc_named_arguments)
    |> case do
      {:ok, %{params_list: params}} ->
        {:ok, nonces_map_from_params(params)}

      error ->
        error
    end
  end

  defp nonces_map_from_params(params) do
    Enum.reduce(params, %{}, fn %{address: address, block_number: block_number, nonce: nonce}, acc ->
      case Hash.Address.cast(address) do
        {:ok, address_hash} ->
          acc
          |> Map.update(
            BlockNumberHelper.next_block_number(block_number),
            %{address_hash => nonce},
            &Map.put(&1, address_hash, nonce)
          )

        _ ->
          acc
      end
    end)
  end

  # Imports all updated signed authorizations, updates relevant addresses and proxy implementations.
  @spec import_authorizations([SignedAuthorization.t()]) :: :ok | {:error, any()}
  defp import_authorizations(signed_authorizations) do
    address_params =
      signed_authorizations
      |> Enum.filter(&(&1.status == :ok))
      # keeps only the latest record for each authority address
      |> Enum.into(%{}, &{&1.authority, SignedAuthorization.to_address_params(&1)})
      |> Map.values()

    # Fetch latest successful authorizations for each authority address
    # and skip importing addresses for which newer authorization already exists.
    # Will only work correctly with concurrency of the fetcher set to 1.
    # Alternative concurrent approach may be considered in the future by moving
    # this check to the DB level inside an "on conflict" clause and introduction
    # of the `last_code_change_nonce` column.
    latest_authorization_nonces =
      address_params
      |> Enum.map(& &1.hash)
      |> address_hashes_to_latest_authorizations()
      |> Enum.into(%{}, &{&1.authority, &1.nonce})

    addresses =
      address_params
      |> Enum.filter(fn %{hash: hash, nonce: nonce} ->
        Decimal.gt?(nonce, Map.get(latest_authorization_nonces, hash, -1))
      end)

    case Chain.import(%{
           addresses: %{
             params: addresses,
             on_conflict: address_on_conflict(),
             fields_to_update: [:contract_code, :nonce]
           },
           signed_authorizations: %{
             params: signed_authorizations |> Enum.map(&SignedAuthorization.to_map/1),
             on_conflict: {:replace, [:status, :updated_at]}
           }
         }) do
      {:ok, %{addresses: addresses}} ->
        Accounts.drop(addresses)

        # Update EIP7702 proxy addresses to avoid inconsistencies between addresses and proxy_implementations tables.
        {contract_addresses, eoa_addresses} = addresses |> Enum.split_with(&Address.smart_contract?/1)

        if !Enum.empty?(eoa_addresses) do
          eoa_addresses
          |> Enum.map(& &1.hash)
          |> Implementation.delete_implementations()
        end

        if !Enum.empty?(contract_addresses) do
          contract_addresses
          |> Implementation.upsert_eip7702_implementations()
        end

        :ok

      {:ok, %{}} ->
        :ok

      {:error, step, reason, _changes_so_far} ->
        Logger.error(
          fn ->
            [
              @failed_to_import,
              inspect(reason)
            ]
          end,
          step: step
        )

        {:error, reason}

      {:error, reason} ->
        Logger.error(fn ->
          [
            @failed_to_import,
            inspect(reason)
          ]
        end)

        {:error, reason}
    end
  end

  defp address_on_conflict do
    from(address in Address,
      update: [
        set: [
          contract_code: fragment("EXCLUDED.contract_code"),
          nonce: fragment("GREATEST(EXCLUDED.nonce, ?)", address.nonce),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", address.updated_at)
        ]
      ]
    )
  end

  defp defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_concurrency: @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :signed_authorization_status]
    ]
  end
end
