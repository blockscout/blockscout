defmodule Explorer.Chain.Cache.TxnBatchs do
  @moduledoc """
  Caches the latest imported transactions
  """

  alias Explorer.Chain.TxnBatch

  use Explorer.Chain.OrderedCache,
    name: :txn_batchs,
    max_size: 51,
    preloads: [
      :batch_index
    ],
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  @type element :: TxnBatch.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%TxnBatch{batch_index: batch_index}) do
    {batch_index}
  end
end
