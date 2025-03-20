defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks do
  @moduledoc """
    Handles the discovery and processing of new and historical confirmations of rollup blocks for an Arbitrum rollup.

    This module orchestrates two distinct confirmation discovery processes:
    1. New confirmations discovery - processes recent confirmations from the
       chain head
    2. Historical confirmations discovery - handles previously missed or unprocessed
       confirmations

    The process involves fetching logs for the `SendRootUpdated` events emitted by
    the Arbitrum Outbox contract. These events indicate the top of the rollup blocks
    confirmed up to a specific point in time. The identified block is used to find
    all blocks beneath it that are not confirmed by other `SendRootUpdated` events.
    All discovered blocks are then linked with the corresponding transaction that
    emitted the `SendRootUpdated` event. Additionally, L2-to-L1 messages included in
    the rollup blocks up to the confirmed top are identified to change their status
    from `:sent` to `:confirmed`.

    Though the `SendRootUpdated` event implies that all rollup blocks below the
    mentioned block are confirmed, the current design of the process attempts to
    match every rollup block to a specific confirmation. This means that if there
    are two confirmations, and the earlier one points to block N while the later
    points to block M (such that M > N), the blocks from N+1 to M are linked with
    the latest confirmation, and blocks from X+1 to N are linked to the earlier
    confirmation (where X is the rollup block mentioned in an even earlier
    confirmation).

    Since the confirmations discovery process is asynchronous with respect to the
    block fetching process and the batches discovery process, there could be
    situations when the information about rollup blocks or their linkage with a
    batch is not available yet. Here is a list of possible scenarios and expected
    behavior:
    1. A rollup block required to proceed with the new confirmation discovery is
      not indexed yet, or the batch where this block is included is not indexed
      yet.
      - The new confirmation discovery process will proceed with discovering new
        confirmations and the L1 blocks range where the confirmation handling is
        aborted will be passed to the historical confirmations discovery process.
    2. A rollup block required to proceed with the historical confirmation discovery
      is not indexed yet, or the batch where this block is included is not indexed
      yet.
      - The historical confirmation discovery process will proceed with the same
        L1 blocks range where the confirmation handling is aborted until this
        confirmation is handled properly.

    As it is clear from the above, the historical confirmation discovery process
    could be interrupted by the new confirmation discovery process. As soon as the
    historical confirmation discovery process reaches the lower end of the L1 block
    range where the new confirmation discovery process is aborted, the historical
    confirmation discovery process will request the database to provide the next L1
    block range of missing confirmations. Such a range could be closed when there
    are end and start L1 blocks in which a missing confirmation is expected, or
    open-ended where the start block is not defined and the end block is the block
    preceding the L1 block where a confirmation was already handled by the discovery
    process.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Discovery, as: ConfirmationsDiscovery
  alias Indexer.Helper, as: IndexerHelper

  require Logger

  @doc """
    Discovers and processes new confirmations of rollup blocks within a calculated block range.

    This function identifies the appropriate L1 block range for discovering new
    rollup confirmations. In order to make sure that no confirmation is missed due
    to re-orgs, it adjusts the range to re-inspect some L1 blocks in the past.
    Therefore the lower bound of the L1 blocks range is identified based on the
    safe block or the block which is considered as safest if RPC does not support
    "safe" block retrieval.

    Then the function fetches logs representing `SendRootUpdated` events within
    the found range to identify the new tops of rollup block confirmations. The
    discovered confirmations are processed to update the status of rollup blocks
    and L2-to-L1 messages accordingly. Eventually, updated rollup blocks, cross-chain
    messages, and newly constructed lifecycle transactions are imported into the
    database.

    After processing the confirmations, the function updates the state to prepare
    for the next iteration. It adjusts the `new_confirmations_start_block` to the
    block number after the last processed block. If a confirmation is missed, the
    range for the next iteration of the historical confirmations discovery process
    is adjusted to re-inspect the range where the confirmation was not handled
    properly.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the L1 outbox address, L1 RPC
                  configurations and the block number limiting the lowest indexed
                  block of the chain.
      - `data`: Contains the starting L1 block number from which to begin the new
                confirmation discovery.

    ## Returns
    - `{:ok, new_state}`: If the discovery process completes successfully.
    - `{:confirmation_missed, new_state}`: If a confirmation is missed and further
      action is needed.
  """
  @spec check_new(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rpc => %{
              :finalized_confirmations => boolean(),
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :rollup_first_block => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            :new_confirmations_start_block => non_neg_integer(),
            :historical_confirmations_end_block => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) ::
          {:ok | :confirmation_missed,
           %{
             :data => %{
               :new_confirmations_start_block => non_neg_integer(),
               :historical_confirmations_end_block => nil | non_neg_integer(),
               :historical_confirmations_start_block => nil | non_neg_integer(),
               optional(any()) => any()
             },
             optional(any()) => any()
           }}
  def check_new(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            rollup_first_block: rollup_first_block
          },
          data: %{
            new_confirmations_start_block: start_block,
            historical_confirmations_end_block: historical_confirmations_end_block
          }
        } = state
      ) do
    {safe_start_block, latest_block} =
      if l1_rpc_config.finalized_confirmations do
        # It makes sense to use "safe" here. Blocks are confirmed with delay in one week
        # (applicable for ArbitrumOne and Nova), so 10 mins delay is not significant.
        # By using "safe" we can avoid re-visiting the same blocks in case of reorgs.
        {safe_chain_block, _} = IndexerHelper.get_safe_block(l1_rpc_config.json_rpc_named_arguments)

        {start_block, safe_chain_block}
      else
        # There are situations when it could be necessary to react on L1 confirmation
        # transactions earlier than the safe block. For example, for testnets.
        # Another situation when the rollup uses L1 RPC which does not support "safe"
        # block retrieval.
        # In both cases it is desired to re-visit some amount head blocks to ensure
        # that no confirmation is missed due to reorgs.

        # The amount of blocks to re-visit depends on the current safe block or the
        # block which is considered as safest if RPC does not support "safe" block.
        {safe_block, latest_block} =
          Rpc.get_safe_and_latest_l1_blocks(l1_rpc_config.json_rpc_named_arguments, l1_rpc_config.logs_block_range)

        # If the new confirmations discovery process does not reach the chain head
        # previously no need to re-visit the blocks.
        {min(start_block, safe_block), latest_block}
      end

    # If ranges for the new confirmations discovery and the historical confirmations
    # discovery are overlapped - it could be after confirmations gap identification,
    # it is necessary to adjust the start block for the new confirmations discovery.
    actual_start_block =
      if is_nil(historical_confirmations_end_block) do
        safe_start_block
      else
        max(safe_start_block, historical_confirmations_end_block + 1)
      end

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if actual_start_block <= end_block do
      log_info("Block range for new rollup confirmations discovery: #{actual_start_block}..#{end_block}")

      # Since for the case l1_rpc_config.finalized_confirmations = false the range
      # actual_start_block..end_block could be larger than L1 RPC max block range for
      # getting logs, it is necessary to divide the range into the chunks.
      results =
        ArbitrumHelper.execute_for_block_range_in_chunks(
          actual_start_block,
          end_block,
          l1_rpc_config.logs_block_range,
          fn chunk_start, chunk_end ->
            ConfirmationsDiscovery.perform(
              outbox_address,
              chunk_start,
              chunk_end,
              l1_rpc_config,
              rollup_first_block
            )
          end,
          true
        )

      # Since halt_on_error was set to true, it is OK to consider the last result
      # only.
      {{start_block, end_block}, retcode} = List.last(results)

      case retcode do
        :ok ->
          {retcode, state_for_next_iteration_new(state, end_block + 1)}

        :confirmation_missed ->
          {retcode, state_for_next_iteration_new(state, end_block + 1, {start_block, end_block})}
      end
    else
      {:ok, state_for_next_iteration_new(state, start_block)}
    end
  end

  # Updates the state for the next iteration of new confirmations discovery.
  @spec state_for_next_iteration_new(
          %{
            :data => map(),
            optional(any()) => any()
          },
          non_neg_integer(),
          nil | {non_neg_integer(), non_neg_integer()}
        ) ::
          %{
            :data => %{
              :new_confirmations_start_block => non_neg_integer(),
              :historical_confirmations_end_block => non_neg_integer(),
              :historical_confirmations_start_block => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          }
  defp state_for_next_iteration_new(prev_state, start_block, historical_blocks \\ nil) do
    data_for_new_confirmations =
      %{new_confirmations_start_block: start_block}

    data_to_update =
      case historical_blocks do
        nil ->
          data_for_new_confirmations

        {start_block, end_block} ->
          Map.merge(data_for_new_confirmations, %{
            historical_confirmations_start_block: start_block,
            historical_confirmations_end_block: end_block
          })
      end

    %{
      prev_state
      | data: Map.merge(prev_state.data, data_to_update)
    }
  end

  @doc """
  Discovers and processes historical confirmations of rollup blocks within a calculated block range.

  This function determines the appropriate L1 block range for discovering
  historical rollup confirmations based on the provided end block or from the
  analysis of confirmations missed in the database. It fetches logs representing
  `SendRootUpdated` events within this range to identify the historical tops of
  rollup block confirmations. The discovered confirmations are processed to update
  the status of rollup blocks and L2-to-L1 messages accordingly. Eventually,
  updated rollup blocks, cross-chain messages, and newly constructed lifecycle
  transactions are imported into the database.

  After processing the confirmations, the function updates the state with the
  blocks range for the next iteration.

  ## Parameters
  - A map containing:
  - `config`: Configuration settings including the L1 outbox address, rollup
              initialization block, RPC configurations, the start block for
              the confirmation discovery and the block number limiting the
              lowest indexed block of the chain.
  - `data`: Contains optional start and end L1 block numbers to limit the range
            for historical confirmation discovery.

  ## Returns
  - `{:ok, new_state}`: If the discovery process completes successfully.
  - `{:confirmation_missed, new_state}`: If a confirmation is missed and further
  action is needed.
  """
  @spec check_unprocessed(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc => %{
              :finalized_confirmations => boolean(),
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_start_block => non_neg_integer(),
            :rollup_first_block => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            :historical_confirmations_end_block => nil | non_neg_integer(),
            :historical_confirmations_start_block => nil | non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) ::
          {:ok | :confirmation_missed,
           %{
             :data => %{
               :historical_confirmations_end_block => nil | non_neg_integer(),
               :historical_confirmations_start_block => nil | non_neg_integer(),
               optional(any()) => any()
             },
             optional(any()) => any()
           }}
  def check_unprocessed(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            l1_start_block: l1_start_block,
            rollup_first_block: rollup_first_block
          },
          data: %{
            historical_confirmations_end_block: expected_confirmation_end_block,
            historical_confirmations_start_block: expected_confirmation_start_block
          }
        } = state
      ) do
    {lowest_l1_block, state} = get_lowest_l1_block_for_confirmations(state)

    {interim_start_block, end_block} =
      case expected_confirmation_end_block do
        nil ->
          # Three options are possible:
          # {nil, nil} - there are no confirmations
          # {nil, value} - there are no confirmations between L1 block corresponding
          #                to the rollup genesis and the L1 block _value_.
          # {lower, higher} - there are no confirmations between L1 block _lower_
          #                   and the L1 block _higher_.
          DbSettlement.l1_blocks_to_expect_rollup_blocks_confirmation(nil)

        _ ->
          {expected_confirmation_start_block, expected_confirmation_end_block}
      end

    with {:end_block_defined, true} <- {:end_block_defined, not is_nil(end_block)},
         {:genesis_not_reached, true} <- {:genesis_not_reached, end_block >= lowest_l1_block} do
      start_block =
        case interim_start_block do
          nil ->
            max(lowest_l1_block, end_block - l1_rpc_config.logs_block_range + 1)

          value ->
            # The interim start block is not nil when a gap between two confirmations
            # identified. Therefore there is no need to go deeper than the interim
            # start block.
            Enum.max([lowest_l1_block, value, end_block - l1_rpc_config.logs_block_range + 1])
        end

      log_info("Block range for historical rollup confirmations discovery: #{start_block}..#{end_block}")

      retcode =
        ConfirmationsDiscovery.perform(
          outbox_address,
          start_block,
          end_block,
          l1_rpc_config,
          rollup_first_block
        )

      case {retcode, start_block == interim_start_block} do
        {:ok, true} ->
          # The situation when the interim start block is equal to the start block
          # means that gap between confirmation has been inspected. It is necessary
          # to identify the next gap.
          {retcode, state_for_next_iteration_historical(state, nil, nil)}

        {:ok, false} ->
          # The situation when the interim start block is not equal to the start block
          # means that the confirmations gap has not been inspected fully yet. It is
          # necessary to continue the confirmations discovery from the interim start
          # block to the the block predecessor of the current start block.
          {retcode, state_for_next_iteration_historical(state, start_block - 1, interim_start_block)}

        {:confirmation_missed, _} ->
          # The situation when the confirmation has been missed. It is necessary to
          # re-do the confirmations discovery for the same block range.
          {retcode, state_for_next_iteration_historical(state, end_block, interim_start_block)}
      end
    else
      # the situation when end block is `nil` is possible when there is no confirmed
      # block in the database and the historical confirmations discovery must start
      # from the L1 block specified as L1 start block (configured, or the latest block number)
      {:end_block_defined, false} -> {:ok, state_for_next_iteration_historical(state, l1_start_block - 1, nil)}
      # If the lowest L1 block with confirmation has been reached during historical confirmations
      # discovery, no further actions are needed.
      {:genesis_not_reached, false} -> {:ok, state_for_next_iteration_historical(state, lowest_l1_block - 1, nil)}
    end
  end

  # Updates the state for the next iteration of historical confirmations discovery.
  @spec state_for_next_iteration_historical(
          %{
            :data => %{
              :historical_confirmations_end_block => non_neg_integer() | nil,
              :historical_confirmations_start_block => non_neg_integer() | nil,
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) ::
          %{
            :data => %{
              :historical_confirmations_end_block => non_neg_integer() | nil,
              :historical_confirmations_start_block => non_neg_integer() | nil,
              optional(any()) => any()
            },
            optional(any()) => any()
          }
  defp state_for_next_iteration_historical(prev_state, end_block, lowest_block_in_gap) when end_block >= 0 do
    %{
      prev_state
      | data: %{
          prev_state.data
          | historical_confirmations_end_block: end_block,
            historical_confirmations_start_block: lowest_block_in_gap
        }
    }
  end

  @doc """
    Determines the lowest L1 block number from which to start discovering confirmations.

    The function either:
    - Returns a cached value if available
    - Queries the database for the batch containing the first rollup block
    - Falls back to `l1_rollup_init_block` if no batch is found (without caching)

    ## Parameters
    - A map containing:
      - `config`: Configuration including `l1_rollup_init_block` and `rollup_first_block`
      - `data`: May contain a cached `lowest_l1_block_for_confirmations`

    ## Returns
    - `{lowest_block, new_state}`: Where `lowest_block` is either:
      - The cached block number
      - The L1 block number of the first batch commitment
      - The `l1_rollup_init_block` as fallback
  """
  @spec get_lowest_l1_block_for_confirmations(%{
          :config => %{
            :l1_rollup_init_block => non_neg_integer(),
            :rollup_first_block => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            optional(:lowest_l1_block_for_confirmations) => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {non_neg_integer(), %{optional(any()) => any()}}
  def get_lowest_l1_block_for_confirmations(
        %{
          config: %{
            l1_rollup_init_block: l1_rollup_init_block,
            rollup_first_block: rollup_first_block
          },
          data: data
        } = state
      ) do
    case Map.get(data, :lowest_l1_block_for_confirmations) do
      nil ->
        # If first block is 0, start from block 1 since block 0 is not included in any batch
        # and therefore has no confirmation. Otherwise use the first block value
        lowest_rollup_block = if rollup_first_block == 0, do: 1, else: rollup_first_block

        case DbSettlement.l1_block_of_confirmation_for_rollup_block(lowest_rollup_block) do
          nil ->
            {l1_rollup_init_block, state}

          block_number ->
            {block_number,
             %{
               state
               | data: Map.put(data, :lowest_l1_block_for_confirmations, block_number)
             }}
        end

      cached_block ->
        {cached_block, state}
    end
  end
end
