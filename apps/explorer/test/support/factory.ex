defmodule Explorer.Factory do
  @dialyzer {:nowarn_function, fields_for: 1}
  use ExMachina.Ecto, repo: Explorer.Repo
  use Explorer.Chain.AddressFactory
  use Explorer.Chain.BlockFactory
  use Explorer.Chain.BlockTransactionFactory
  use Explorer.Chain.FromAddressFactory
  use Explorer.Chain.InternalTransactionFactory
  use Explorer.Chain.LogFactory
  use Explorer.Chain.ReceiptFactory
  use Explorer.Chain.ToAddressFactory
  use Explorer.Chain.TransactionFactory
  use Explorer.Market.MarketHistoryFactory
end
