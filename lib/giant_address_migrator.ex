defmodule GiantAddressMigrator do
  def migrate do
    for n <- 1..20 do
      chunk_size = 500_000
      lower = n * chunk_size - chunk_size
      upper = n * chunk_size

      IO.inspect("fetching results between #{lower} and #{upper}")
      work_on_transactions_between_ids(lower, upper)
    end
  end

  def work_on_transactions_between_ids(lower, upper) do
    query = """
    select transactions.id, from_addresses.address_id as from_address_id, to_addresses.address_id as to_address_id
    FROM transactions
    inner join from_addresses on from_addresses.transaction_id = id
    inner join to_addresses on to_addresses.transaction_id = id
    where transactions.id >= #{lower} AND transactions.id < #{upper}
    ;
    """

    {:ok, result} = Explorer.Repo.query(query, [])
    IO.inspect("got em!")

    result.rows
    |> Enum.each(&sweet_update/1)
  end

  def sweet_update([transaction_id, from_address_id, to_address_id]) do
    query = """
    UPDATE transactions SET from_address_id = $1, to_address_id = $2 WHERE id = $3
    """

    {:ok, status} = Explorer.Repo.query(query, [from_address_id, to_address_id, transaction_id])
  end

  def sweet_update(_), do: nil
end
