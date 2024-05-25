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

  import Explorer.Chain.Cache.CeloCoreContracts,
    only: [
      atom_to_contract_name: 0
    ]

  alias Mix.Task
  alias EthereumJSONRPC.Logs
  alias Indexer.Helper

  @registry_proxy_contract_address "0x000000000000000000000000000000000000ce10"
  @registry_updated_event_signature "0x4166d073a7a5e704ce0db7113320f88da2457f872d46dc020c805c562c1582a0"
  @batch_size 100_000

  def run(_) do
    Task.run("app.start")
    contract_names = atom_to_contract_name() |> Map.values()
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
    chunks_number = ceil(latest_block_number / @batch_size)

    core_contract_addresses =
      0..chunks_number
      |> Enum.reduce([], fn current_chunk, acc ->
        chunk_start = @batch_size * current_chunk
        chunk_end = min(@batch_size * (current_chunk + 1) - 1, latest_block_number)

        Helper.log_blocks_chunk_handling(chunk_start, chunk_end, 0, latest_block_number, nil, :L1)

        requests = [
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

        {:ok, responses} =
          Helper.repeated_call(
            &json_rpc/2,
            [requests, json_rpc_named_arguments],
            fn message -> "Could not fetch logs: #{message}" end,
            3
          )

        {:ok, result} = Logs.from_responses(responses)

        result ++ acc
      end)
      |> Enum.reduce(
        %{},
        fn log, acc ->
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
        end
      )

    core_contract_addresses
    |> Jason.encode!()
    |> IO.puts()
  end
end
