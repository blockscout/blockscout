defmodule Explorer.Chain.Cache.PendingTransactions do
  @moduledoc """
  Caches the latest pending transactions
  """

  alias Explorer.Chain.Transaction

  use Explorer.Chain.OrderedCache,
    name: :pending_transactions,
    max_size: 51,
    preloads: [
      :block,
      created_contract_address: :names,
      from_address: :names,
      to_address: :names,
      token_transfers: :token,
      token_transfers: :from_address,
      token_transfers: :to_address
    ],
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  @type element :: Transaction.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%Transaction{inserted_at: inserted_at, hash: hash}) do
    {inserted_at, hash}
  end

  def update_pending(transactions) when is_nil(transactions), do: :ok

  def update_pending(transactions) do
    transactions
    |> Enum.filter(&pending?(&1))
    |> update()
  end

  defp pending?(transaction) do
    is_nil(transaction.block_hash) and (is_nil(transaction.error) or transaction.error != "dropped/replaced")
  end
end
