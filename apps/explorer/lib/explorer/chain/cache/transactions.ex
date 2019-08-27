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
    ]

  @type element :: Transaction.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%Transaction{block_number: block_number, index: index}) do
    {block_number, index}
  end
end
