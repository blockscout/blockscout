defmodule Explorer.Chain.Cache.ExternalTransactions do
  @moduledoc """
  Caches the latest imported external transactions
  """

  alias Explorer.Chain.ExternalTransaction

  use Explorer.Chain.OrderedCache,
    #ids_list_key: :ext_transactions,
    name: :ext_transactions,
    max_size: 51,
    preloads: [
      :block,
      created_contract_address: :names,
      from_address: :names,
      to_address: :names,
    ],
    ttl_check_interval: 7200,
    global_ttl: 7200

  @type element :: ExternalTransaction.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%ExternalTransaction{block_number: block_number, index: index}) do
    IO.puts("ExternalTransaction element_to_id: #{inspect({block_number, index})}")
    IO.inspect(Application.get_env(:explorer, __MODULE__))
    {block_number, index}
  end
end
