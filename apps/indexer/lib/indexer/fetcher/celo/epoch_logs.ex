defmodule Indexer.Fetcher.Celo.EpochLogs do
  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2
    ]

  alias EthereumJSONRPC.Logs
  alias Indexer.Helper

  def fetch(blocks, json_rpc_named_arguments) do
    if Application.get_env(:explorer, :chain_type) == :celo do
      requests =
        blocks
        |> Enum.with_index()
        |> Enum.map(fn {%{number: number}, request_id} ->
          Logs.request(
            request_id,
            %{
              :fromBlock => integer_to_quantity(number),
              :toBlock => integer_to_quantity(number)
            }
          )
        end)

      error_message = "Could not fetch epoch logs"

      with {:ok, responses} <-
             Helper.repeated_call(
               &json_rpc/2,
               [requests, json_rpc_named_arguments],
               error_message,
               3
             ),
           {:ok, logs} <- Logs.from_responses(responses) do
        logs
        |> Enum.filter(&(&1.transaction_hash == &1.block_hash))
        |> Enum.map(&Map.put(&1, :transaction_hash, nil))
      end
    else
      []
    end
  end
end
