defmodule Explorer.Resource do

  @moduledoc "Looks up and fetches resource based on its handle (either an id or hash)"

  import Ecto.Query, only: [from: 2]

  alias Explorer.Block
  alias Explorer.Address
  alias Explorer.Repo.NewRelic, as: Repo
  alias Explorer.Transaction

  def lookup(hash) when byte_size(hash) > 42, do: fetch_transaction(hash)

  def lookup(hash) when byte_size(hash) == 42, do: fetch_address(hash)

  def lookup(number), do: fetch_block(number)

  def fetch_address(hash) do
    query = from address in Address,
      where: fragment("lower(?)", address.hash) == ^String.downcase(hash),
      limit: 1

    Repo.one(query)
  end

  def fetch_transaction(hash) do
    query = from transaction in Transaction,
      where: fragment("lower(?)", transaction.hash) == ^String.downcase(hash),
      limit: 1

    Repo.one(query)
  end

  def fetch_block(block_number) when is_bitstring(block_number) do
    case Integer.parse(block_number) do
        {number, ""} -> fetch_block(number)
        _ -> nil
    end
  end

  def fetch_block(number) when is_integer(number) do
    query = from b in Block,
      where: b.number == ^number,
      limit: 1

    Repo.one(query)
  end
end
