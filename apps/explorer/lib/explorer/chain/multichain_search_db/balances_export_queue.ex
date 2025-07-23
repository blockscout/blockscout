defmodule Explorer.Chain.MultichainSearchDb.BalancesExportQueue do
  @moduledoc """
  Tracks token and coin balances, pending for export to the Multichain Service database.
  """

  use Explorer.Schema
  import Ecto.Query
  alias Ecto.Multi
  alias Explorer.Repo
  alias Explorer.Chain.{Hash, Wei}

  @required_attrs ~w(address_hash token_contract_address_hash_or_native)a
  @optional_attrs ~w(value token_id retries_number)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @primary_key false
  typed_schema "multichain_search_db_export_balances_queue" do
    field(:id, :integer, primary_key: true, null: false)
    field(:address_hash, Hash.Address, null: false)
    field(:token_contract_address_hash_or_native, :binary, null: false)
    field(:value, Wei)
    field(:token_id, :decimal)
    field(:retries_number, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
  Streams a batch of multichain database balances that need to be retried for export.

  This function selects specific fields from the export records and applies a reducer function to each entry in the stream, accumulating the result. Optionally, the stream can be limited based on the `limited?` flag.

  ## Parameters

    - `initial`: The initial accumulator value.
    - `reducer`: A function that takes an entry (as a map) and the current accumulator, returning the updated accumulator.
    - `limited?` (optional): A boolean indicating whether to apply a fetch limit to the stream. Defaults to `false`.

  ## Returns

    - `{:ok, accumulator}`: A tuple containing `:ok` and the final accumulator after processing the stream.
  """
  @spec stream_multichain_db_balances_batch(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_multichain_db_balances_batch(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    __MODULE__
    |> select([export], %{
      address_hash: export.address_hash,
      token_contract_address_hash_or_native: export.token_contract_address_hash_or_native,
      value: export.value,
      token_id: export.token_id
    })
    |> add_balances_queue_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  defp add_balances_queue_fetcher_limit(query, false), do: query

  defp add_balances_queue_fetcher_limit(query, true) do
    balances_queue_fetcher_limit =
      Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue)[:init_limit]

    limit(query, ^balances_queue_fetcher_limit)
  end

  @doc """
  Returns an Ecto query that defines the default behavior for handling conflicts
  when inserting into the `multichain_search_db_export_balances_queue` table.

  On conflict, this query:
    - Increments the `retries_number` field by 1 (or sets it to 1 if it was `nil`).
    - Sets the `updated_at` field to the greatest value between the current and the excluded `updated_at`.

  This is typically used with `on_conflict: default_on_conflict()` in Ecto insert operations.
  """
  @spec default_on_conflict :: Ecto.Query.t()
  def default_on_conflict do
    from(
      multichain_search_db_export_balances_queue in __MODULE__,
      update: [
        set: [
          retries_number: fragment("COALESCE(?, 0) + 1", multichain_search_db_export_balances_queue.retries_number),
          updated_at:
            fragment("GREATEST(?, EXCLUDED.updated_at)", multichain_search_db_export_balances_queue.updated_at)
        ]
      ]
    )
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @spec delete_elements_from_queue_by_params([map()]) :: list()
  def delete_elements_from_queue_by_params(balances) do
    q =
      Enum.reduce(balances, nil, fn balance, acc ->
        balance_address_hash = balance.address_hash

        balance_token_contract_address_hash_or_native_binary =
          if byte_size(balance.token_contract_address_hash_or_native) == 6 do
            balance.token_contract_address_hash_or_native
          else
            "0x" <> hex = balance.token_contract_address_hash_or_native
            hex |> Base.decode16(case: :lower) |> elem(1)
          end

        balance_token_id = balance.token_id

        query =
          from(
            b in __MODULE__,
            where: b.address_hash == ^balance_address_hash,
            where: b.token_contract_address_hash_or_native == ^balance_token_contract_address_hash_or_native_binary,
            where:
              fragment(
                "COALESCE(?, -1::numeric) = COALESCE(?::numeric, -1::numeric)",
                b.token_id,
                ^balance_token_id
              )
          )

        if is_nil(acc) do
          query
        else
          acc
          |> union(^query)
        end
      end)

    elements = Repo.all(q)

    delete_elements =
      elements
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {elem, ind}, acc ->
        acc
        |> Multi.delete(String.to_atom("delete_#{ind}"), elem)
      end)

    Repo.transact(delete_elements)
  end
end
