defmodule Indexer.Fetcher.Celo.ValidatorGroupVotes do
  @moduledoc """
  Fetches validator group votes from the Celo blockchain.
  """

  use GenServer
  use Indexer.Fetcher

  import Explorer.Helper,
    only: [
      truncate_address_hash: 1,
      safe_parse_non_negative_integer: 1
    ]

  alias EthereumJSONRPC.Logs
  alias Explorer.Application.Constants
  alias Explorer.Chain
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Transform.Addresses

  require Logger

  @last_fetched_block_key "celo_validator_group_votes_last_fetched_block_number"

  @max_request_retries 3

  @validator_group_vote_activated_topic "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
  @validator_group_active_vote_revoked_topic "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8"

  @spec fetch(block_number :: EthereumJSONRPC.block_number()) :: :ok
  def fetch(block_number) do
    GenServer.call(__MODULE__, {:fetch, block_number}, 60_000)
  end

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(args) do
    Logger.metadata(fetcher: :celo_validator_group_votes)

    {
      :ok,
      %{
        config: %{
          batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size],
          json_rpc_named_arguments: args[:json_rpc_named_arguments]
        },
        data: %{}
      },
      {:continue, :ok}
    }
  end

  @impl GenServer
  def handle_continue(
        :ok,
        %{
          config: %{
            batch_size: batch_size,
            json_rpc_named_arguments: json_rpc_named_arguments
          }
        } = state
      ) do
    {:ok, latest_block_number} =
      EthereumJSONRPC.fetch_block_number_by_tag(
        "latest",
        json_rpc_named_arguments
      )

    Logger.info("Fetching votes up to latest block number #{latest_block_number}")

    fetch_up_to_block_number(latest_block_number, batch_size, json_rpc_named_arguments)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(
        {:fetch, block_number},
        _from,
        %{
          config: %{
            batch_size: batch_size,
            json_rpc_named_arguments: json_rpc_named_arguments
          }
        } = state
      ) do
    Logger.info("Fetching votes on demand up to block number #{block_number}")

    fetch_up_to_block_number(block_number, batch_size, json_rpc_named_arguments)

    {:reply, :ok, state}
  end

  defp fetch_up_to_block_number(block_number, batch_size, json_rpc_named_arguments) do
    {:ok, last_fetched_block_number} =
      @last_fetched_block_key
      |> Constants.get_constant_value()
      |> case do
        nil -> CeloCoreContracts.get_first_update_block_number(:election)
        value -> safe_parse_non_negative_integer(value)
      end

    if last_fetched_block_number < block_number do
      block_range = last_fetched_block_number..block_number

      block_range
      |> IndexerHelper.range_chunk_every(batch_size)
      |> Enum.each(&process_chunk(&1, block_range, json_rpc_named_arguments))

      Logger.info("Fetched validator group votes up to block number #{block_number}")
    else
      Logger.info("No new validator group votes to fetch")
    end
  end

  defp process_chunk(_..chunk_to_block//_ = chunk, block_range, json_rpc_named_arguments) do
    validator_group_votes =
      chunk
      |> fetch_logs_chunk(block_range, json_rpc_named_arguments)
      |> Enum.map(&log_to_entry/1)

    addresses_params =
      Addresses.extract_addresses(%{
        celo_validator_group_votes: validator_group_votes
      })

    {:ok, _imported} =
      Chain.import(%{
        addresses: %{params: addresses_params},
        celo_validator_group_votes: %{params: validator_group_votes}
      })

    Constants.set_constant_value(@last_fetched_block_key, to_string(chunk_to_block))

    :ok
  end

  defp fetch_logs_chunk(
         chunk_from_block..chunk_to_block//_,
         from_block..to_block//_,
         json_rpc_named_arguments
       ) do
    IndexerHelper.log_blocks_chunk_handling(chunk_from_block, chunk_to_block, from_block, to_block, nil, :L1)

    {:ok, election_contract_address} = CeloCoreContracts.get_address(:election, chunk_from_block)

    requests =
      [
        @validator_group_active_vote_revoked_topic,
        @validator_group_vote_activated_topic
      ]
      |> Enum.with_index()
      |> Enum.map(fn {topic, request_id} ->
        Logs.request(
          request_id,
          %{
            from_block: chunk_from_block,
            to_block: chunk_to_block,
            address: election_contract_address,
            topics: [topic]
          }
        )
      end)

    {:ok, responses} =
      IndexerHelper.repeated_batch_rpc_call(
        requests,
        json_rpc_named_arguments,
        fn message -> Logger.error("Could not fetch logs: #{message}") end,
        @max_request_retries
      )

    {:ok, logs} = Logs.from_responses(responses)

    logs
  end

  defp log_to_entry(log) do
    type =
      case log.first_topic do
        @validator_group_vote_activated_topic -> :activated
        @validator_group_active_vote_revoked_topic -> :revoked
      end

    account_address_hash = truncate_address_hash(log.second_topic)
    group_address_hash = truncate_address_hash(log.third_topic)

    %{
      account_address_hash: account_address_hash,
      group_address_hash: group_address_hash,
      type: type,
      block_number: log.block_number,
      block_hash: log.block_hash,
      transaction_hash: log.transaction_hash
    }
  end
end
