defmodule Explorer.Chain.DenormalizationHelper do
  @moduledoc false

  alias Explorer.Chain.Cache.BackgroundMigrations

  def extend_block_necessity(opts, necessity \\ :optional) do
    if denormalization_finished?() do
      opts
    else
      Keyword.update(opts, :necessity_by_association, %{:block => necessity}, &Map.put(&1, :block, necessity))
    end
  end

  def extend_transaction_block_necessity(opts, necessity \\ :optional) do
    if denormalization_finished?() do
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

  def extend_transaction_preload(preloads) do
    if denormalization_finished?() do
      preloads
    else
      [transaction: :block] ++ (preloads -- [:transaction])
    end
  end

  def extend_block_preload(preloads) do
    if denormalization_finished?() do
      preloads
    else
      [:block | preloads]
    end
  end

  def denormalization_finished?, do: BackgroundMigrations.get_denormalization_finished()
end
