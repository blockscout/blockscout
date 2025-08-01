defmodule Indexer.Fetcher.Celo.EpochLogs do
  @moduledoc """
  Fetches logs that are not linked to transaction, but to the block.
  """

  import Explorer.Chain.Celo.Helper,
    only: [
      epoch_block_number?: 1,
      pre_migration_block_number?: 1
    ]

  alias EthereumJSONRPC.{Logs, Transport}
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain.TokenTransfer
  alias Indexer.Transform.Celo.ValidatorEpochPaymentDistributions

  require Logger

  @max_request_retries 3

  @epoch_block_targets [
    # TargetVotingYieldUpdated
    epoch_rewards: "0x49d8cdfe05bae61517c234f65f4088454013bafe561115126a8fe0074dc7700e",
    celo_token: TokenTransfer.constant(),
    usd_token: TokenTransfer.constant(),
    validators: ValidatorEpochPaymentDistributions.signature(),
    # ValidatorScoreUpdated
    validators: "0xedf9f87e50e10c533bf3ae7f5a7894ae66c23e6cbbe8773d7765d20ad6f995e9",
    # EpochRewardsDistributedToVoters
    election: "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"
  ]

  @default_block_targets [
    # GasPriceMinimumUpdated
    gas_price_minimum: "0x6e53b2f8b69496c2a175588ad1326dbabe2f66df4d82f817aeca52e3474807fb"
  ]

  @spec fetch(
          [Indexer.Transform.Blocks.block()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: Logs.t()
  def fetch(blocks, json_rpc_named_arguments)

  def fetch(blocks, json_rpc_named_arguments) do
    if Application.get_env(:explorer, :chain_type) == :celo do
      do_fetch(blocks, json_rpc_named_arguments)
    else
      []
    end
  end

  @spec do_fetch(
          [Indexer.Transform.Blocks.block()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: Logs.t()
  defp do_fetch(blocks, json_rpc_named_arguments) do
    requests =
      blocks
      |> Enum.filter(&pre_migration_block_number?(&1.number))
      |> Enum.reduce({[], 0}, &blocks_reducer/2)
      |> elem(0)
      |> Enum.reverse()
      |> Enum.concat()

    with {:ok, responses} <- do_requests(requests, json_rpc_named_arguments),
         {:ok, logs} <- Logs.from_responses(responses) do
      logs
      |> Enum.filter(&(&1.transaction_hash == &1.block_hash))
      |> Enum.map(&Map.put(&1, :transaction_hash, nil))
    end
  end

  # Workaround in order to fix block fetcher tests.
  #
  # If the requests is empty, we still send the requests to the JSON RPC
  @spec do_requests(
          [Transport.request()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, [map()]}
  defp do_requests(requests, json_rpc_named_arguments) do
    if Enum.empty?(requests) do
      {:ok, []}
    else
      IndexerHelper.repeated_batch_rpc_call(
        requests,
        json_rpc_named_arguments,
        fn message -> "Could not fetch epoch logs: #{message}" end,
        @max_request_retries
      )
    end
  end

  @spec blocks_reducer(
          Indexer.Transform.Blocks.block(),
          {[Transport.request()], integer()}
        ) :: {[Transport.request()], integer()}
  defp blocks_reducer(%{number: number}, {acc, start_request_id}) do
    targets =
      @default_block_targets ++
        if epoch_block_number?(number) do
          @epoch_block_targets
        else
          []
        end

    requests =
      targets
      |> Enum.map(fn {contract_atom, topic} ->
        res = CeloCoreContracts.get_address(contract_atom, number)
        {res, topic}
      end)
      |> Enum.split_with(&match?({{:ok, _address}, _topic}, &1))
      |> tap(fn {_, not_found} ->
        if not Enum.empty?(not_found) do
          Logger.info("Could not fetch addresses for the following contract atoms: #{inspect(not_found)}")
        end
      end)
      |> elem(0)
      |> Enum.with_index(start_request_id)
      |> Enum.map(fn {{{:ok, address}, topic}, request_id} ->
        Logs.request(
          request_id,
          %{
            from_block: number,
            to_block: number,
            address: address,
            topics: [topic]
          }
        )
      end)

    next_start_request_id = start_request_id + length(requests)
    {[requests | acc], next_start_request_id}
  end
end
