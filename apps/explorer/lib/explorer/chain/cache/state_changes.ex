defmodule Explorer.Chain.Cache.StateChanges do
  @moduledoc """
  Caches the transaction state changes for pagination
  """

  alias Explorer.Chain.{Hash, OrderedCache}
  alias Explorer.Chain.Transaction.StateChange

  defstruct [:transaction_hash, :state_changes]

  @type t :: %__MODULE__{
          transaction_hash: Hash.t(),
          state_changes: [StateChange.t()]
        }

  use OrderedCache,
    name: :state_changes,
    max_size: 10

  @type element :: t()

  @type id :: Hash.t()

  def element_to_id(%__MODULE__{transaction_hash: tx_hash}) do
    tx_hash
  end

  # in order to always keep just requested changes
  def prevails?(a, b) do
    a == b
  end
end
