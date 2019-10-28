defmodule Explorer.Chain.Cache.Transactions do
  @moduledoc """
  Caches the latest imported transactions
  """

  alias Explorer.Chain.Transaction

  use Explorer.Chain.OrderedCache,
    name: :transactions,
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

  def element_to_id(%Transaction{block_number: block_number, index: index}) do
    {block_number, index}
  end
end
