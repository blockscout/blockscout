defmodule Indexer.Fetcher.Beacon.Deposit do
  @moduledoc """
  Fetches deposit data from the beacon chain.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias ABI.Event
  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.{Data, Wei}
  alias Explorer.Repo
  alias Indexer.Fetcher.Beacon.Client

  defstruct [
    :interval,
    :batch_size,
    :deposit_contract_address_hash,
    :domain_deposit,
    :genesis_fork_version,
    :deposit_index,
    :last_processed_log_block_number,
    :last_processed_log_index
  ]

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl GenServer
  def init(_opts) do
    Logger.metadata(fetcher: :beacon_deposit)

    {:ok, nil, {:continue, nil}}
  end

  @impl GenServer
  def handle_continue(nil, _state) do
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
          last_processed_log_index: last_processed_deposit.log_index
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
          last_processed_log_index: last_processed_log_index
        } = state
      ) do
    deposits =
      deposit_contract_address_hash
      |> Deposit.get_logs_with_deposits(
        last_processed_log_block_number,
        last_processed_log_index,
        batch_size
      )
      |> Enum.map(&log_to_deposit/1)

    # todo: sequential? check is removed as a hard requirement for deposits indexing
    # since block ranges are found where node doesn't return deposits
    # thus making the deposit index sequence non-sequential.
    # We need a separate process which will monitor missed deposits
    # after we check the nature of those missing deposit indexes.
    case sequential?(deposit_index, deposits) do
      {:error, prev, curr} ->
        Logger.error("Non-sequential deposits detected: #{inspect(prev)} followed by #{inspect(curr)}")

      _ ->
        :ok
    end

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

  defp log_to_deposit(log) do
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
        log.first_topic && log.first_topic.bytes,
        nil,
        nil,
        nil,
        log.data.bytes
      )

    %{
      pubkey: %Data{bytes: pubkey},
      withdrawal_credentials: %Data{bytes: withdrawal_credentials},
      amount: amount |> Decimal.new() |> Wei.from(:gwei),
      signature: %Data{bytes: signature},
      index: index,
      from_address_hash: log.from_address_hash,
      transaction_hash: log.transaction_hash,
      block_hash: log.block_hash,
      block_number: log.block_number,
      block_timestamp: log.block_timestamp,
      log_index: log.index,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp sequential?(last_processed_deposit_index, deposits) do
    Enum.reduce_while(deposits, %{index: last_processed_deposit_index}, fn
      %{index: i}, %{index: prev} when i == prev + 1 ->
        {:cont, %{index: i}}

      %{index: i}, %{index: prev} ->
        {:halt, {:error, prev, i}}
    end)
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
