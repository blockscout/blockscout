defmodule Explorer.Chain.SmartContractTransactionCount do
  @moduledoc """
  The representation of a verified Smart Contract transaction count.
  """

  require Logger

  use Explorer.Schema

  @typedoc """
  * `transaction_count` - indicates how many times the contract has been invoked.
  """

  @type t :: %Explorer.Chain.SmartContractTransactionCount{
          transaction_count: non_neg_integer()
        }

  @primary_key {:address_hash, :string, []}
  schema "smart_contracts_transaction_counts" do
    field(:transaction_count, :integer)
  end
end
