defmodule Explorer.Workers.RefreshBalance do
  @moduledoc """
    Refreshes the Credit and Debit balance views.
  """

  alias Explorer.Credit
  alias Explorer.Debit

  def perform do
    Credit.refresh()
    Debit.refresh()
  end

  def perform_later do
    Exq.enqueue(Exq.Enqueuer, "default", __MODULE__, [])
  end
end
