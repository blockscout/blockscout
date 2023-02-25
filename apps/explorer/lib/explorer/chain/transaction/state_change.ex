defmodule Explorer.Chain.Transaction.StateChange do
  defstruct [:coin_or_token_transfers, :address, :balance_before, :balance_after, :balance_diff, :miner?]
end
