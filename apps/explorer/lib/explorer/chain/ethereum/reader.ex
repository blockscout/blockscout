# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Ethereum.Reader do
  @moduledoc "Contains read functions for Ethereum health metrics (beacon deposits and withdrawals)."

  import Ecto.Query, only: [from: 2]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.Withdrawal
  alias Explorer.Prometheus.Instrumenter

  @doc """
    Gets information about the latest beacon deposit and calculates average time between deposits, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two deposits exist:
      `{:ok, %{latest_deposit_l1_number: integer, latest_deposit_timestamp: DateTime.t(), average_deposit_time: integer}}`
      where:
        * latest_deposit_l1_number - number of the block where the latest deposit was included.
        * latest_deposit_timestamp - timestamp of the latest deposit block.
        * average_deposit_time - average number of seconds between deposits for the last 100 deposits.

    - If less than two deposits exist: `{:error, :not_found}`.
  """
  @spec get_latest_deposit_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_deposit_info(options \\ []) do
    query =
      from(d in Deposit,
        order_by: [desc: d.index],
        limit: 100,
        select: %{
          number: d.block_number,
          timestamp: d.block_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_deposit_metric(items)
  end

  @doc """
    Gets information about the latest beacon withdrawal and calculates average time between withdrawals, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two withdrawals exist:
      `{:ok, %{latest_withdrawal_l2_number: integer, latest_withdrawal_timestamp: DateTime.t(), average_withdrawal_time: integer}}`
      where:
        * latest_withdrawal_l2_number - number of the block where the latest withdrawal was included.
        * latest_withdrawal_timestamp - timestamp of the latest withdrawal block.
        * average_withdrawal_time - average number of seconds between withdrawals for the last 100 withdrawals.

    - If less than two withdrawals exist: `{:error, :not_found}`.
  """
  @spec get_latest_withdrawal_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_withdrawal_info(options \\ []) do
    query =
      from(w in Withdrawal,
        inner_join: b in assoc(w, :block),
        where: b.consensus == true,
        order_by: [desc: w.index],
        limit: 100,
        select: %{
          number: b.number,
          timestamp: b.timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_withdrawal_metric(items)
  end
end
