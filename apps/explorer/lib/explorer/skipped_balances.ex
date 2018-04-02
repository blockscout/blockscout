defmodule Explorer.SkippedBalances do
  @moduledoc "Gets a list of Addresses that do not have balances."

  alias Explorer.Address
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  def fetch(count) do
    query =
      from(
        address in Address,
        select: address.hash,
        where: is_nil(address.balance),
        limit: ^count
      )

    query
    |> Repo.all()
  end
end
