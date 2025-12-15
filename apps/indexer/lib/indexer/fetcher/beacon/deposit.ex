defmodule Indexer.Fetcher.Beacon.Deposit do
  @moduledoc """
  Fetches deposit data from the beacon chain.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias ABI.Event
  alias Ecto.Changeset
  alias EthereumJSONRPC.Block, as: EthereumJSONRPCBlock
  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.{Block, Data, Hash, Wei}
  alias Explorer.Repo
  alias Indexer.Fetcher.Beacon.Client
  alias Indexer.Helper

  defstruct [
    :interval,
    :batch_size,
    :deposit_contract_address_hash,
    :domain_deposit,
    :genesis_fork_version,
    :deposit_index,
    :last_processed_log_block_number,
    :last_processed_log_index,
    :json_rpc_named_arguments
  ]

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl GenServer
  def init(opts) do
    Logger.metadata(fetcher: :beacon_deposit)

    json_rpc_named_arguments = opts[:json_rpc_named_arguments]

    if !json_rpc_named_arguments do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.init to allow for json_rpc calls when running."
    end

    {:ok, nil, {:continue, json_rpc_named_arguments}}
  end

  @impl GenServer
  def handle_continue(json_rpc_named_arguments, _state) do
    chain_id = Application.get_env(:indexer, :chain_id)

    case Client.get_spec() do
      {:ok,
       %{
         "data" => %{
           "DEPOSIT_CHAIN_ID" => ^chain_id,
           "DEPOSIT_CONTRACT_ADDRESS" => deposit_contract_address_hash,
           "DOMAIN_DEPOSIT" => "0x" <> domain_deposit_hex,
           "GENESIS_FORK_VERSION" => "0x" <> genesis_fork_version_hex
         }
       }} ->
        last_processed_deposit = Deposit.get_latest_deposit() || %{index: -1, block_number: -1, log_index: -1}

        state = %__MODULE__{
          interval: Application.get_env(:indexer, __MODULE__)[:interval],
          batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size],
          deposit_contract_address_hash: deposit_contract_address_hash,
          domain_deposit: Base.decode16!(domain_deposit_hex, case: :mixed),
          genesis_fork_version: Base.decode16!(genesis_fork_version_hex, case: :mixed),
          deposit_index: last_processed_deposit.index,
          last_processed_log_block_number: last_processed_deposit.block_number,
          last_processed_log_index: last_processed_deposit.log_index,
          json_rpc_named_arguments: json_rpc_named_arguments
        }

        Process.send_after(self(), :process_logs, state.interval)

        {:noreply, state}

      {:ok,
       %{
         "data" => %{
           "DEPOSIT_CHAIN_ID" => chain_id,
           "DEPOSIT_CONTRACT_ADDRESS" => _deposit_contract_address_hash,
           "DOMAIN_DEPOSIT" => "0x" <> _domain_deposit_hex,
           "GENESIS_FORK_VERSION" => "0x" <> _genesis_fork_version_hex
         }
       }} ->
        Logger.error("Misconfigured CHAIN_ID or INDEXER_BEACON_RPC_URL, CHAIN_ID from the node: #{inspect(chain_id)}")
        {:stop, :wrong_chain_id, nil}

      {:ok, data} ->
        Logger.error("Unexpected format on beacon spec endpoint: #{inspect(data)}")
        {:stop, :unexpected_format, nil}

      {:error, reason} ->
        Logger.error("Failed to fetch beacon spec: #{inspect(reason)}")
        {:stop, :fetch_failed, nil}
    end
  end

  @impl GenServer
  def handle_cast({:lost_consensus, block_number}, %__MODULE__{} = state) do
    {_deleted_deposits_count, deleted_deposits} =
      Repo.delete_all(
        from(
          d in Deposit,
          where: d.block_number > ^block_number,
          select: d.index
        ),
        timeout: :infinity
      )

    deposit_index = Enum.min(deleted_deposits, fn -> state.deposit_index + 1 end)

    {:noreply,
     %{
       state
       | deposit_index: deposit_index - 1,
         last_processed_log_block_number: block_number,
         last_processed_log_index: -1
     }}
  rescue
    postgrex_error in Postgrex.Error ->
      Logger.error(
        "Error while trying to delete reorged Beacon Deposits: #{Exception.format(:error, postgrex_error, __STACKTRACE__)}. Retrying."
      )

      GenServer.cast(self(), {:lost_consensus, block_number})
      {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        :process_logs,
        %__MODULE__{
          interval: interval,
          batch_size: batch_size,
          deposit_contract_address_hash: deposit_contract_address_hash,
          domain_deposit: domain_deposit,
          genesis_fork_version: genesis_fork_version,
          deposit_index: deposit_index,
          last_processed_log_block_number: last_processed_log_block_number,
          last_processed_log_index: last_processed_log_index,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    deposits =
      deposit_contract_address_hash
      |> Deposit.get_logs_with_deposits(
        last_processed_log_block_number,
        last_processed_log_index,
        batch_size
      )
      |> Enum.map(&db_log_to_deposit/1)

    result =
      case find_missing_ranges(deposit_index, deposits) do
        [_ | _] = missing_ranges ->
          Logger.error(
            "Non-sequential deposits detected, missing ranges are: #{inspect(missing_ranges)}, trying to fetch from the node"
          )

          case fetch_and_process_logs_from_node(
                 deposit_index,
                 last_processed_log_block_number,
                 missing_ranges,
                 deposits,
                 deposit_contract_address_hash,
                 json_rpc_named_arguments
               ) do
            {:ok, deposits} ->
              {:ok, deposits}

            {:error, reason} ->
              Logger.error("Failed to fetch deposit logs from node: #{inspect(reason)}")
              Process.send_after(self(), :process_logs, interval * 30)
              :error
          end

        _ ->
          {:ok, deposits}
      end

    case result do
      {:ok, deposits} ->
        {deposits_count, _} =
          Repo.insert_all(Deposit, set_status(deposits, domain_deposit, genesis_fork_version),
            on_conflict: :replace_all,
            conflict_target: [:index]
          )

        if deposits_count < batch_size do
          Process.send_after(self(), :process_logs, interval)
        else
          Process.send(self(), :process_logs, [])
        end

        last_deposit =
          List.last(deposits, %{
            index: state.deposit_index,
            block_number: state.last_processed_log_block_number,
            log_index: state.last_processed_log_index
          })

        {:noreply,
         %__MODULE__{
           state
           | deposit_index: last_deposit.index,
             last_processed_log_block_number: last_deposit.block_number,
             last_processed_log_index: last_deposit.log_index
         }}

      _ ->
        {:noreply, state}
    end
  end

  defp fetch_and_process_logs_from_node(
         last_processed_deposit_index,
         last_processed_deposit_block_number,
         missing_ranges,
         deposits,
         deposit_contract_address_hash,
         json_rpc_named_arguments
       ) do
    with {:ok, deposits_from_node} <-
           missing_ranges
           |> Task.async_stream(
             fn {from_deposit_index, to_deposit_index} ->
               do_fetch_and_process_logs_from_node(
                 last_processed_deposit_index,
                 last_processed_deposit_block_number,
                 from_deposit_index,
                 to_deposit_index,
                 deposits,
                 deposit_contract_address_hash,
                 json_rpc_named_arguments
               )
             end,
             max_concurrency: 5,
             timeout: :infinity
           )
           |> Enum.reduce_while({:ok, []}, fn
             {:ok, {:ok, deposits_from_node}}, {:ok, acc} ->
               {:cont, {:ok, deposits_from_node ++ acc}}

             {:ok, {:error, reason}}, _ ->
               {:halt, {:error, reason}}

             {:exit, reason}, _ ->
               {:halt, {:error, reason}}
           end),
         merged_deposits =
           deposits
           |> Map.new(fn d -> {d.index, d} end)
           |> Map.merge(deposits_from_node |> Map.new(fn d -> {d.index, d} end))
           |> Map.values()
           |> Enum.sort_by(& &1.index),
         [] <- find_missing_ranges(last_processed_deposit_index, merged_deposits) do
      {:ok, merged_deposits}
    else
      [_ | _] = missing_ranges ->
        Logger.error("Still missing deposit ranges after fetching from the node: #{inspect(missing_ranges)}")
        {:error, :missing_ranges_after_node_fetch}

      err ->
        err
    end
  end

  defp do_fetch_and_process_logs_from_node(
         last_processed_deposit_index,
         last_processed_deposit_block_number,
         from_deposit_index,
         to_deposit_index,
         deposits,
         deposit_contract_address_hash,
         json_rpc_named_arguments
       ) do
    from_deposit_block_number =
      if last_processed_deposit_index == from_deposit_index do
        last_processed_deposit_block_number
      else
        Enum.find(deposits, fn %{index: i} -> i == from_deposit_index end).block_number
      end

    to_deposit_block_number = Enum.find(deposits, fn %{index: i} -> i == to_deposit_index end).block_number

    with {:ok, logs} <-
           Helper.get_logs(
             max(0, from_deposit_block_number),
             max(0, to_deposit_block_number),
             to_string(deposit_contract_address_hash),
             [Deposit.event_signature()],
             json_rpc_named_arguments
           ) do
      node_logs_to_deposits(logs, json_rpc_named_arguments)
    end
  end

  defp node_logs_to_deposits(logs, json_rpc_named_arguments) do
    blocks_from_db =
      logs
      |> Enum.map(fn l -> l["blockHash"] end)
      |> Enum.uniq()
      |> Block.by_hashes_query()
      |> Repo.all()
      |> Map.new(fn b -> {b.hash, b} end)

    logs_with_missing_blocks =
      logs
      |> Enum.reject(fn l ->
        {:ok, l_block_hash} = Hash.Full.cast(l["blockHash"])
        Map.has_key?(blocks_from_db, l_block_hash)
      end)

    blocks_from_node =
      logs_with_missing_blocks
      |> Helper.get_blocks_by_events(json_rpc_named_arguments, 3)
      |> Map.new(fn b ->
        b = b |> EthereumJSONRPCBlock.to_elixir() |> EthereumJSONRPCBlock.elixir_to_params()
        b = %Block{} |> Changeset.cast(b, ~w(hash number timestamp)a) |> Changeset.apply_changes()
        {b.hash, b}
      end)

    blocks = Map.merge(blocks_from_db, blocks_from_node)

    logs
    |> Enum.reduce_while({:ok, []}, fn l, {:ok, acc} ->
      case node_log_to_deposit(l, blocks) do
        {:ok, deposit} ->
          {:cont, {:ok, [deposit | acc]}}

        {:error, reason} ->
          Logger.error("Failed to decode deposit log from node: #{inspect(reason)}")
          {:halt, {:error, :missing_block}}
      end
    end)
  end

  @abi ABI.parse_specification(
         [
           %{
             "anonymous" => false,
             "inputs" => [
               %{
                 "indexed" => false,
                 "internalType" => "bytes",
                 "name" => "pubkey",
                 "type" => "bytes"
               },
               %{
                 "indexed" => false,
                 "internalType" => "bytes",
                 "name" => "withdrawal_credentials",
                 "type" => "bytes"
               },
               %{
                 "indexed" => false,
                 "internalType" => "bytes",
                 "name" => "amount",
                 "type" => "bytes"
               },
               %{
                 "indexed" => false,
                 "internalType" => "bytes",
                 "name" => "signature",
                 "type" => "bytes"
               },
               %{
                 "indexed" => false,
                 "internalType" => "bytes",
                 "name" => "index",
                 "type" => "bytes"
               }
             ],
             "name" => "DepositEvent",
             "type" => "event"
           }
         ],
         include_events?: true
       )

  defp db_log_to_deposit(log) do
    do_log_to_deposit(
      log.first_topic,
      log.data,
      log.from_address_hash,
      log.transaction_hash,
      log.block_hash,
      log.block_number,
      log.block_timestamp,
      log.index
    )
  end

  defp node_log_to_deposit(
         %{
           "topics" => [str_first_topic],
           "data" => str_data,
           "address" => str_from_address_hash,
           "transactionHash" => str_transaction_hash,
           "blockHash" => str_block_hash,
           "logIndex" => str_log_index
         },
         blocks
       ) do
    {:ok, block_hash} = Hash.Full.cast(str_block_hash)

    case blocks[block_hash] do
      nil ->
        {:error, :missing_block}

      block ->
        {:ok, first_topic} = Data.cast(str_first_topic)
        {:ok, data} = Data.cast(str_data)
        {:ok, from_address_hash} = Hash.Address.cast(str_from_address_hash)
        {:ok, transaction_hash} = Hash.Full.cast(str_transaction_hash)

        {:ok,
         do_log_to_deposit(
           first_topic,
           data,
           from_address_hash,
           transaction_hash,
           block.hash,
           block.number,
           block.timestamp,
           EthereumJSONRPC.quantity_to_integer(str_log_index)
         )}
    end
  end

  defp do_log_to_deposit(
         first_topic,
         data,
         from_address_hash,
         transaction_hash,
         block_hash,
         block_number,
         block_timestamp,
         log_index
       ) do
    {_,
     [
       {"pubkey", "bytes", false, pubkey},
       {"withdrawal_credentials", "bytes", false, withdrawal_credentials},
       {"amount", "bytes", false, <<amount::unsigned-little-64>>},
       {"signature", "bytes", false, signature},
       {"index", "bytes", false, <<index::unsigned-little-64>>}
     ]} =
      Event.find_and_decode(
        @abi,
        first_topic.bytes,
        nil,
        nil,
        nil,
        data.bytes
      )

    %{
      pubkey: %Data{bytes: pubkey},
      withdrawal_credentials: %Data{bytes: withdrawal_credentials},
      amount: amount |> Decimal.new() |> Wei.from(:gwei),
      signature: %Data{bytes: signature},
      index: index,
      from_address_hash: from_address_hash,
      transaction_hash: transaction_hash,
      block_hash: block_hash,
      block_number: block_number,
      block_timestamp: block_timestamp,
      log_index: log_index,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp find_missing_ranges(last_processed_deposit_index, deposits) do
    result =
      Enum.reduce(deposits, %{index: last_processed_deposit_index, gaps: []}, fn
        %{index: i}, %{index: prev, gaps: gaps} when i - prev <= 1 ->
          %{index: i, gaps: gaps}

        %{index: i}, %{index: prev, gaps: gaps} ->
          %{index: i, gaps: [{prev, i} | gaps]}
      end)

    Enum.reverse(result.gaps)
  end

  defp set_status(deposits, domain_deposit, genesis_fork_version) do
    {deposits_to_query, deposits_acc, _valid_pubkeys_acc} =
      Enum.reduce(deposits, {[], [], MapSet.new()}, fn deposit, {deposit_to_query, deposits_acc, valid_pubkeys_acc} ->
        valid_signature? = verify(deposit, domain_deposit, genesis_fork_version)

        new_valid_pubkeys_acc =
          if valid_signature? do
            MapSet.put(valid_pubkeys_acc, deposit.pubkey)
          else
            valid_pubkeys_acc
          end

        if MapSet.member?(valid_pubkeys_acc, deposit.pubkey) or valid_signature? do
          {deposit_to_query, [Map.put(deposit, :status, :pending) | deposits_acc], new_valid_pubkeys_acc}
        else
          {[deposit | deposit_to_query], deposits_acc, valid_pubkeys_acc}
        end
      end)

    deposits_to_query_pubkeys = Enum.map(deposits_to_query, & &1.pubkey)

    query =
      from(deposit in Deposit,
        where: deposit.status != :invalid,
        where: deposit.pubkey in ^deposits_to_query_pubkeys,
        select: deposit.pubkey
      )

    valid_pubkeys = query |> Repo.all() |> MapSet.new()

    deposits_with_status =
      deposits_to_query
      |> Enum.map(fn deposit ->
        if MapSet.member?(valid_pubkeys, deposit.pubkey) do
          Map.put(deposit, :status, :pending)
        else
          Map.put(deposit, :status, :invalid)
        end
      end)

    deposits_with_status ++ deposits_acc
  end

  @zero_genesis_validators_root :binary.copy(<<0x00>>, 32)

  defp verify(deposit, domain_deposit, genesis_fork_version) do
    deposit_message_root =
      hash_tree_root_deposit_message(
        deposit.pubkey.bytes,
        deposit.withdrawal_credentials.bytes,
        deposit.amount |> Wei.to(:gwei) |> Decimal.to_integer()
      )

    domain =
      compute_domain(
        domain_deposit,
        genesis_fork_version,
        @zero_genesis_validators_root
      )

    signing_root = compute_signing_root(deposit_message_root, domain)

    ExEthBls.verify(deposit.pubkey.bytes, signing_root, deposit.signature.bytes)
  end

  defp hash_tree_root_deposit_message(pubkey, withdrawal_credentials, amount) do
    pubkey_packed = pack_basic_type(pubkey)
    pubkey_root = merkleize_chunks(pubkey_packed)

    wc_packed = pack_basic_type(withdrawal_credentials)
    wc_root = merkleize_chunks(wc_packed)

    amount_bytes = <<amount::unsigned-little-64>>
    amount_packed = pack_basic_type(amount_bytes)
    amount_root = merkleize_chunks(amount_packed)

    field_roots = [pubkey_root, wc_root, amount_root]
    merkleize_chunks(field_roots)
  end

  defp pack_basic_type(value) do
    chunk_size = 32
    padding_needed = rem(chunk_size - rem(byte_size(value), chunk_size), chunk_size)
    padded = value <> :binary.copy(<<0>>, padding_needed)

    for <<chunk::binary-size(chunk_size) <- padded>>, do: chunk
  end

  defp merkleize_chunks([chunk]), do: chunk

  defp merkleize_chunks(chunks) when is_list(chunks) do
    padded_chunks = pad_to_next_power_of_two(chunks)
    merkleize_recursive(padded_chunks)
  end

  defp merkleize_recursive([single_chunk]), do: single_chunk

  defp merkleize_recursive(chunks) do
    next_level =
      chunks
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [left, right] -> :crypto.hash(:sha256, left <> right)
        [single] -> single
      end)

    merkleize_recursive(next_level)
  end

  defp pad_to_next_power_of_two(list) do
    length = length(list)
    next_power = next_power_of_two(length)
    padding_needed = next_power - length
    zero_chunk = :binary.copy(<<0>>, 32)
    list ++ List.duplicate(zero_chunk, padding_needed)
  end

  defp next_power_of_two(n) when n <= 1, do: 1

  defp next_power_of_two(n) do
    2 |> :math.pow(:math.ceil(:math.log2(n))) |> round()
  end

  defp compute_domain(domain_type, fork_version, genesis_validators_root) do
    fork_data_root = compute_container_hash_tree_root([fork_version, genesis_validators_root])
    domain_type <> binary_part(fork_data_root, 0, 28)
  end

  defp compute_signing_root(deposit_message_root, domain) do
    compute_container_hash_tree_root([deposit_message_root, domain])
  end

  defp compute_container_hash_tree_root(field_values) do
    field_roots =
      field_values
      |> Enum.map(fn value ->
        value
        |> pack_basic_type()
        |> merkleize_chunks()
      end)

    merkleize_chunks(field_roots)
  end
end
