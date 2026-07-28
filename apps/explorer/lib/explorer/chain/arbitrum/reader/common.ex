# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Arbitrum.Reader.Common do
  @moduledoc """
    Provides common database query functions for Arbitrum-specific data that are shared
    between different Blockscout components.

    This module serves as a central location for core query functionality that needs to
    be accessed from different logical parts of the application, such as:

    * Web API handlers (e.g. `Explorer.Chain.Arbitrum.Reader.API.Settlement`)
    * Chain indexer components (e.g. `Explorer.Chain.Arbitrum.Reader.Indexer.Settlement`)
    * Other potential consumers

    The functions in this module are designed to be configurable in terms of database
    selection (primary vs replica) through options parameters. This allows the calling
    modules to maintain their specific database access patterns while sharing the core
    query logic.

    For example, API handlers typically use replica databases to reduce load on the
    primary database, while indexer components require immediate consistency and thus
    use the primary database. This module accommodates both use cases through options
    parameters.

    When adding new functions to this module, ensure they:
    * Are needed by multiple components of the application
    * Accept options for configuring database selection
    * Implement core query logic that can be reused across different contexts
  """

  import Ecto.Query, only: [from: 2]
  import Explorer.Chain, only: [select_repo: 1, string_to_full_hash: 1]

  alias Explorer.Chain.Arbitrum.{
    BatchBlock,
    DaMultiPurposeRecord,
    L1Batch,
    Message
  }

  alias Explorer.Chain.Block, as: FullBlock

  alias Explorer.Prometheus.Instrumenter

  @doc """
    Retrieves the number of the highest confirmed rollup block.

    ## Parameters
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - The number of the highest confirmed rollup block, or `nil` if no confirmed rollup blocks are found.
  """
  @spec highest_confirmed_block(api?: boolean()) :: FullBlock.block_number() | nil
  def highest_confirmed_block(options) do
    query =
      from(
        rb in BatchBlock,
        where: not is_nil(rb.confirmation_id),
        select: rb.block_number,
        order_by: [desc: rb.block_number],
        limit: 1
      )

    select_repo(options).one(query)
  end

  @doc """
    Retrieves an AnyTrust keyset from the database using the provided keyset hash.

    ## Parameters
    - `keyset_hash`: A binary representing the hash of the keyset to be retrieved.
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - A map containing information about the AnyTrust keyset, otherwise an empty map.
  """
  @spec get_anytrust_keyset(binary(), api?: boolean()) :: map()
  def get_anytrust_keyset("0x" <> <<_::binary-size(64)>> = keyset_hash, options) do
    get_anytrust_keyset(keyset_hash |> string_to_full_hash() |> Kernel.elem(1) |> Map.get(:bytes), options)
  end

  def get_anytrust_keyset(keyset_hash, options) do
    query =
      from(
        da_records in DaMultiPurposeRecord,
        where: da_records.data_key == ^keyset_hash and da_records.data_type == 1
      )

    case select_repo(options).one(query) do
      nil -> %{}
      keyset -> keyset.data
    end
  end

  @doc """
    Retrieves information about the latest batches including:
    - The latest batch number
    - The timestamp when the latest batch was committed to the parent chain
    - The average time between parent chain transactions for the latest 10 batches

    ## Parameters
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - `{:ok, %{latest_batch_number: number, latest_batch_timestamp: timestamp, average_batch_time: seconds}}`
      if batches are found
    - `{:error, :not_found}` if no batches are found
  """
  @spec get_latest_batch_info(api?: boolean()) ::
          {:ok,
           %{
             latest_batch_number: non_neg_integer(),
             latest_batch_timestamp: DateTime.t(),
             average_batch_time: non_neg_integer()
           }}
          | {:error, :not_found}
  def get_latest_batch_info(options) do
    import Ecto.Query

    # Query to get the latest 10 batches with their commitment transactions
    latest_batches_query =
      from(batch in L1Batch,
        join: tx in assoc(batch, :commitment_transaction),
        order_by: [desc: batch.number],
        limit: 10,
        select: %{
          number: batch.number,
          timestamp: tx.timestamp
        }
      )

    items = select_repo(options).all(latest_batches_query)

    Instrumenter.prepare_batch_metric(items)
  end

  @doc """
    Gets information about the latest deposit (L1->L2 message) and calculates the average
    time between deposits, in seconds.

    ## Parameters
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - `{:ok, %{latest_deposit_l1_number: number, latest_deposit_timestamp: timestamp, average_deposit_time: seconds}}`
      if deposits are found
    - `{:error, :not_found}` if no deposits are found
  """
  @spec get_latest_deposit_info(api?: boolean()) ::
          {:ok,
           %{
             latest_deposit_l1_number: non_neg_integer(),
             latest_deposit_timestamp: DateTime.t(),
             average_deposit_time: non_neg_integer()
           }}
          | {:error, :not_found}
  def get_latest_deposit_info(options) do
    query =
      from(m in Message,
        where: m.direction == :to_l2 and not is_nil(m.origination_timestamp),
        order_by: [desc: m.message_id],
        limit: 100,
        select: %{
          number: m.originating_transaction_block_number,
          timestamp: m.origination_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_deposit_metric(items)
  end

  @doc """
    Gets information about the latest withdrawal (L2->L1 message) and calculates the average
    time between withdrawals, in seconds.

    ## Parameters
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - `{:ok, %{latest_withdrawal_l2_number: number, latest_withdrawal_timestamp: timestamp, average_withdrawal_time: seconds}}`
      if withdrawals are found
    - `{:error, :not_found}` if no withdrawals are found
  """
  @spec get_latest_withdrawal_info(api?: boolean()) ::
          {:ok,
           %{
             latest_withdrawal_l2_number: non_neg_integer(),
             latest_withdrawal_timestamp: DateTime.t(),
             average_withdrawal_time: non_neg_integer()
           }}
          | {:error, :not_found}
  def get_latest_withdrawal_info(options) do
    query =
      from(m in Message,
        where: m.direction == :from_l2 and not is_nil(m.origination_timestamp),
        order_by: [desc: m.message_id],
        limit: 100,
        select: %{
          number: m.originating_transaction_block_number,
          timestamp: m.origination_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_withdrawal_metric(items)
  end
end
