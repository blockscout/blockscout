defmodule Indexer.Fetcher.Celo.EpochLogs do
  @moduledoc """
  Fetches logs that are not associated which are not linked to transaction, but
  to the block.
  """

  import Explorer.Chain.Celo.Helper, only: [epoch_block_number?: 1]

  alias EthereumJSONRPC.Logs
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain.TokenTransfer
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  @max_request_retries 3

  @epoch_block_targets [
    epoch_rewards: [
      # TargetVotingYieldUpdated
      "0x49d8cdfe05bae61517c234f65f4088454013bafe561115126a8fe0074dc7700e"
    ],
    celo_token: [TokenTransfer.constant()],
    usd_token: [TokenTransfer.constant()],
    validators: [
      ValidatorEpochPaymentDistributions.signature(),
      # ValidatorScoreUpdated
      "0xedf9f87e50e10c533bf3ae7f5a7894ae66c23e6cbbe8773d7765d20ad6f995e9"
    ],
    election: [
      # EpochRewardsDistributedToVoters
      "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"
    ]
  ]

  @default_block_targets [
    gas_price_minimum: [
      # GasPriceMinimumUpdated
      "0x6e53b2f8b69496c2a175588ad1326dbabe2f66df4d82f817aeca52e3474807fb"
    ]
  ]

  @spec fetch(
          [Indexer.Transform.Blocks.block()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: Logs.t()
  def fetch(blocks, json_rpc_named_arguments)

  if Application.compile_env(:explorer, :chain_type) == :celo do
    def fetch(blocks, json_rpc_named_arguments) do
      requests =
        blocks
        |> Enum.reduce({[], 0}, fn %{number: number}, {acc, start_request_id} ->
          targets =
            @default_block_targets ++
              if epoch_block_number?(number) do
                @epoch_block_targets
              else
                []
              end

          requests =
            targets
            |> Enum.map(fn {contract_atom, topics} ->
              {:ok, address} = CeloCoreContracts.get_address(contract_atom, number)
              {address, topics}
            end)
            |> Enum.reject(&match?({nil, _targets}, &1))
            |> Enum.with_index(start_request_id)
            |> Enum.map(fn {{address, topics}, request_id} ->
              Logs.request(
                request_id,
                %{
                  from_block: number,
                  to_block: number,
                  address: address,
                  topics: topics
                }
              )
            end)

          next_start_request_id = start_request_id + length(targets)
          {[requests | acc], next_start_request_id}
        end)
        |> elem(0)
        |> Enum.reverse()
        |> Enum.concat()

      with {:ok, responses} <-
             IndexerHelper.repeated_batch_rpc_call(
               requests,
               json_rpc_named_arguments,
               fn message -> "Could not fetch epoch logs: #{message}" end,
               @max_request_retries
             ),
           {:ok, logs} <- Logs.from_responses(responses) do
        logs
        |> Enum.filter(&(&1.transaction_hash == &1.block_hash))
        |> Enum.map(&Map.put(&1, :transaction_hash, nil))
      end
    end
  else
    def fetch(_blocks, _json_rpc_named_arguments), do: []
  end
end
