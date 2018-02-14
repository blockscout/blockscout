defmodule Explorer.Factory do
  @dialyzer {:nowarn_function, fields_for: 1}
  use ExMachina.Ecto, repo: Explorer.Repo
  use Explorer.AddressFactory
  use Explorer.BlockFactory
  use Explorer.BlockTransactionFactory
  use Explorer.FromAddressFactory
  use Explorer.LogFactory
  use Explorer.ToAddressFactory
  use Explorer.TransactionFactory
  use Explorer.TransactionReceiptFactory
end
