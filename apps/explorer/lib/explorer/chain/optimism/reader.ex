# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.Reader do
  @moduledoc "Contains read functions for Optimism modules."
  import Ecto.Query,
    only: [from: 2]

  import Explorer.Chain, only: [select_repo: 1]
  alias Explorer.Chain.Block
  alias Explorer.Chain.Optimism.{Deposit, FrameSequence, Withdrawal}
  alias Explorer.Prometheus.Instrumenter

  @doc """
    Gets information about the latest batch and calculates average time between batches, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two batches exist:
      `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`
      where:
        * latest_batch_number - id of the latest batch in the database.
        * latest_batch_timestamp - when the latest batch was committed to L1.
        * average_batch_time - average number of seconds between batches for the last 100 batches.

    - If less than two batches exist: `{:error, :not_found}`.
  """
  @spec get_latest_batch_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_batch_info(options \\ []) do
    query =
      from(fs in FrameSequence,
        where: fs.view_ready == true,
        order_by: [desc: fs.id],
        limit: 5,
        select: %{
          number: fs.id,
          timestamp: fs.l1_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_batch_metric(items)
  end

  @doc """
    Gets information about the latest deposit and calculates average time between deposits, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two deposits exist:
      `{:ok, %{latest_deposit_l1_number: integer, latest_deposit_timestamp: DateTime.t(), average_deposit_time: integer}}`
      where:
        * latest_deposit_l1_number - L1 block number of the latest deposit in the database.
        * latest_deposit_timestamp - when the latest deposit was made on L1.
        * average_deposit_time - average number of seconds between deposits for the last 100 deposits.

    - If less than two deposits exist: `{:error, :not_found}`.
  """
  @spec get_latest_deposit_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_deposit_info(options \\ []) do
    query =
      from(d in Deposit,
        where: not is_nil(d.l1_block_timestamp),
        order_by: [desc: d.l1_block_number],
        limit: 100,
        select: %{
          number: d.l1_block_number,
          timestamp: d.l1_block_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_deposit_metric(items)
  end

  @doc """
    Gets information about the latest withdrawal and calculates average time between withdrawals, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two withdrawals exist:
      `{:ok, %{latest_withdrawal_l2_number: integer, latest_withdrawal_timestamp: DateTime.t(), average_withdrawal_time: integer}}`
      where:
        * latest_withdrawal_l2_number - L2 block number of the latest withdrawal in the database.
        * latest_withdrawal_timestamp - when the latest withdrawal was initiated on L2.
        * average_withdrawal_time - average number of seconds between withdrawals for the last 100 withdrawals.

    - If less than two withdrawals exist: `{:error, :not_found}`.
  """
  @spec get_latest_withdrawal_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_withdrawal_info(options \\ []) do
    query =
      from(w in Withdrawal,
        inner_join: l2_block in Block,
        on: w.l2_block_number == l2_block.number,
        order_by: [desc: w.msg_nonce],
        limit: 100,
        select: %{
          number: w.l2_block_number,
          timestamp: l2_block.timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_withdrawal_metric(items)
  end
end
