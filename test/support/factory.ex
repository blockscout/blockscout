defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo
  use Explorer.BlockFactory
end
