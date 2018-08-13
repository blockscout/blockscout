defmodule ExplorerWeb.FakeAdapter do
  alias Explorer.Chain.Address
  alias Explorer.Repo

  def address_estimated_count do
    Repo.aggregate(Address, :count, :hash)
  end
end
