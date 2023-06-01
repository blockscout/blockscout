defmodule Explorer.Chain.Cache.TransactionsApiV2 do
  @moduledoc """
  Caches the latest imported transactions
  """

  alias Explorer.Chain.Transaction

  use Explorer.Chain.OrderedCache,
    name: :transactions_api_v2,
    max_size: 51,
    preloads: [
      :block,
      created_contract_address: :names,
      from_address: :names,
      to_address: :names
    ],
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  @type element :: Transaction.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%Transaction{block_number: block_number, index: index}) do
    {block_number, index}
  end
end
