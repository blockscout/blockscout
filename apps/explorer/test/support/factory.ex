defmodule Explorer.Factory do
  @dialyzer {:nowarn_function, fields_for: 1}
  use ExMachina.Ecto, repo: Explorer.Repo
  use Explorer.Chain.AddressFactory
  use Explorer.Chain.BlockFactory
  use Explorer.Chain.InternalTransactionFactory
  use Explorer.Chain.LogFactory
  use Explorer.Chain.ReceiptFactory
  use Explorer.Chain.TransactionFactory
end
