defmodule Explorer.AddressForm do
  @moduledoc false
  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Transaction

  def build(address) do
    address
    |> Map.merge(%{
      balance: address |> calculate_balance,
    })
  end

  def calculate_balance(address) do
    Decimal.sub(credits(address), debits(address))
  end

  def credits(address) do
    query = from transaction in Transaction,
      join: to_address in assoc(transaction, :to_address),
      select: sum(transaction.value),
      where: to_address.id == ^address.id
    Repo.one(query) || Decimal.new(0)
  end

  def debits(address) do
    query = from transaction in Transaction,
      join: from_address in assoc(transaction, :from_address),
      select: sum(transaction.value),
      where: from_address.id == ^address.id
    Repo.one(query) || Decimal.new(0)
  end
end
