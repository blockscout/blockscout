defmodule Explorer.Factory do
  @dialyzer {:nowarn_function, fields_for: 1}
  use ExMachina.Ecto, repo: Explorer.Repo
  use Explorer.BlockFactory
  use Explorer.TransactionFactory
end
