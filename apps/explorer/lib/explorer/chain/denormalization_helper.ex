defmodule Explorer.Chain.DenormalizationHelper do
  @moduledoc """
  Helper functions for dynamic logic based on denormalization migration completeness
  """

  alias Explorer.Chain.Cache.BackgroundMigrations

  @spec extend_block_necessity(keyword(), :optional | :required) :: keyword()
  def extend_block_necessity(opts, necessity \\ :optional) do
    if transactions_denormalization_finished?() do
      opts
    else
      Keyword.update(opts, :necessity_by_association, %{:block => necessity}, &Map.put(&1, :block, necessity))
    end
  end

  @spec extend_transaction_block_necessity(keyword(), :optional | :required) :: keyword()
  def extend_transaction_block_necessity(opts, necessity \\ :optional) do
    if transactions_denormalization_finished?() do
      opts
    else
      Keyword.update(
        opts,
        :necessity_by_association,
        %{[transaction: :block] => necessity},
        &(&1 |> Map.delete(:transaction) |> Map.put([transaction: :block], necessity))
      )
    end
  end

  @spec extend_transaction_preload(list()) :: list()
  def extend_transaction_preload(preloads) do
    if transactions_denormalization_finished?() do
      preloads
    else
      [transaction: :block] ++ (preloads -- [:transaction])
    end
  end

  @spec extend_block_preload(list()) :: list()
  def extend_block_preload(preloads) do
    if transactions_denormalization_finished?() do
      preloads
    else
      [:block | preloads]
    end
  end

  @doc """
    Checks if the transaction denormalization process has been completed.

    This function retrieves the status of the transaction denormalization
    background migration. The denormalization process copies `block.consensus` and
    `block.timestamp` to the respective fields in the transactions table for all
    transactions with a `block_hash`.

    ## Returns
    - `true` if all transactions with a `block_hash` have `block_consensus` and
      `block_timestamp` set.
    - `false` if the migration is still ongoing or the status is unknown.
  """
  @spec transactions_denormalization_finished?() :: boolean()
  def transactions_denormalization_finished?, do: BackgroundMigrations.get_transactions_denormalization_finished()

  def tt_denormalization_finished?, do: BackgroundMigrations.get_tt_denormalization_finished()
end
