defmodule Mix.Tasks.FetchCeloCoreContracts do
  @moduledoc """
  Fetch the addresses of celo core contracts: `mix help celo-contracts`
  """
  @shortdoc "Fetches the addresses of celo core contracts"

  use Mix.Task

  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2
    ]

  import Explorer.Helper,
    only: [
      decode_data: 2,
      truncate_address_hash: 1
    ]

  alias Mix.Task
  alias EthereumJSONRPC.Logs
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Indexer.Helper

  @registry_proxy_contract_address "0x000000000000000000000000000000000000ce10"
  @registry_updated_event_signature "0x4166d073a7a5e704ce0db7113320f88da2457f872d46dc020c805c562c1582a0"
  @carbon_offsetting_fund_set_event_signature "0xe296227209b47bb8f4a76768ebd564dcde1c44be325a5d262f27c1fd4fd4538b"
  @fee_beneficiary_set_event_signature "0xf7015098f8d6fa48f0560725ffd5f81bf687ee5ac45153b590bdcb04648bbdd3"
  @burn_fraction_set_event_signature "0x41c679f4bcdc2c95f79a3647e2237162d9763d86685ef6c667781230c8ba9157"
  @chunk_size 200_000

  def run(_) do
    Task.run("app.start")
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    atom_to_contract_name = CeloCoreContracts.atom_to_contract_name()
    atom_to_contract_event_names = CeloCoreContracts.atom_to_contract_event_names()
    contract_names = atom_to_contract_name |> Map.values()
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)

    core_contract_addresses =
      0..latest_block_number
      |> fetch_logs_by_chunks(
        fn chunk_start, chunk_end ->
          [
            Logs.request(
              0,
              %{
                fromBlock: integer_to_quantity(chunk_start),
                toBlock: integer_to_quantity(chunk_end),
                address: @registry_proxy_contract_address,
                topics: [@registry_updated_event_signature]
              }
            )
          ]
        end,
        json_rpc_named_arguments
      )
      |> Enum.reduce(%{}, fn log, acc ->
        [contract_name] = decode_data(log.data, [:string])
        new_contract_address = truncate_address_hash(log.third_topic)

        entry = %{
          address: new_contract_address,
          updated_at_block_number: log.block_number
        }

        if contract_name in contract_names do
          acc
          |> Map.update(
            contract_name,
            [entry],
            &(&1 ++ [entry])
          )
        else
          acc
        end
      end)

    epoch_rewards_events =
      fetch_events_for_contract(
        [@carbon_offsetting_fund_set_event_signature],
        :epoch_rewards,
        core_contract_addresses,
        latest_block_number,
        json_rpc_named_arguments
      )
      |> Map.new(fn {address, logs} ->
        entries =
          logs
          |> Enum.map(
            &%{
              address: truncate_address_hash(&1.second_topic),
              updated_at_block_number: &1.block_number
            }
          )

        event_name = atom_to_contract_event_names[:epoch_rewards][:carbon_offsetting_fund_set]
        {address, %{event_name => entries}}
      end)

    fee_handler_events =
      fetch_events_for_contract(
        [
          @fee_beneficiary_set_event_signature,
          @burn_fraction_set_event_signature
        ],
        :fee_handler,
        core_contract_addresses,
        latest_block_number,
        json_rpc_named_arguments
      )
      |> Map.new(fn {address, logs} ->
        topic_to_logs = logs |> Enum.group_by(& &1.first_topic)

        fee_beneficiary_set_event_name = atom_to_contract_event_names[:fee_handler][:fee_beneficiary_set]
        burn_fraction_set_event_name = atom_to_contract_event_names[:fee_handler][:burn_fraction_set]

        {
          address,
          %{
            fee_beneficiary_set_event_name =>
              topic_to_logs
              |> Map.get(@fee_beneficiary_set_event_signature, [])
              |> Enum.map(
                &%{
                  address: truncate_address_hash(&1.data),
                  updated_at_block_number: &1.block_number
                }
              ),
            burn_fraction_set_event_name =>
              topic_to_logs
              |> Map.get(@burn_fraction_set_event_signature, [])
              |> Enum.map(fn log ->
                [fraction] = decode_data(log.data, [{:int, 256}])

                %{
                  value: fraction / 10 ** 24,
                  updated_at_block_number: log.block_number
                }
              end)
          }
        }
      end)

    core_contracts_json =
      %{
        "addresses" => core_contract_addresses,
        "events" => %{
          atom_to_contract_name[:epoch_rewards] => epoch_rewards_events,
          atom_to_contract_name[:fee_handler] => fee_handler_events
        }
      }
      |> Jason.encode!()

    IO.puts("CELO_CORE_CONTRACTS=#{core_contracts_json}")
  end

  defp fetch_logs_by_chunks(from_block..to_block, requests_func, json_rpc_named_arguments) do
    chunks_number = ceil((to_block - from_block + 1) / @chunk_size)

    0..chunks_number
    |> Enum.reduce([], fn current_chunk, acc ->
      chunk_start = from_block + @chunk_size * current_chunk
      chunk_end = min(chunk_start + @chunk_size - 1, to_block)

      Helper.log_blocks_chunk_handling(chunk_start, chunk_end, 0, to_block, nil, :L1)

      requests = requests_func.(chunk_start, chunk_end)

      {:ok, responses} =
        Helper.repeated_call(
          &json_rpc/2,
          [requests, json_rpc_named_arguments],
          fn message -> "Could not fetch logs: #{message}" end,
          3
        )

      {:ok, logs} = Logs.from_responses(responses)

      acc ++ logs
    end)
  end

  defp fetch_events_for_contract(
         event_signatures,
         contract_atom,
         core_contract_addresses,
         latest_block_number,
         json_rpc_named_arguments
       ) do
    contract_name =
      CeloCoreContracts.atom_to_contract_name()
      |> Map.get(contract_atom)

    core_contract_addresses
    |> Map.get(contract_name)
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn
      [entry, %{updated_at_block_number: to_block}] ->
        {entry, to_block}

      [entry] ->
        {entry, latest_block_number}
    end)
    |> Enum.map(fn {%{address: address}, to_block} ->
      logs =
        fetch_logs_by_chunks(
          0..to_block,
          fn chunk_start, chunk_end ->
            event_signatures
            |> Enum.with_index()
            |> Enum.map(fn {signature, index} ->
              Logs.request(
                index,
                %{
                  fromBlock: integer_to_quantity(chunk_start),
                  toBlock: integer_to_quantity(chunk_end),
                  address: address,
                  topics: [signature]
                }
              )
            end)
          end,
          json_rpc_named_arguments
        )

      {address, logs}
    end)
  end
end
