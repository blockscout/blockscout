defmodule Explorer.Chain.TransactionError do
  @moduledoc """
  Stores errors for transactions and internal transactions.
  """

  use Explorer.Schema

  alias Explorer.Repo

  typed_schema "transaction_errors" do
    field(:message, :string, null: false)

    timestamps(updated_at: false)
  end

  def changeset(%__MODULE__{} = transaction_error, attrs) do
    cast(transaction_error, attrs, [:message])
  end

  def id_to_error(nil), do: nil

  def id_to_error(id) do
    __MODULE__
    |> where([te], te.id == ^id)
    |> select([te], te.message)
    |> Repo.one()
  end

  def find_or_create(error_message) do
    [error_message]
    |> find_or_create_multiple()
    |> Map.get(error_message)
  end

  def find_or_create_multiple(error_messages) do
    error_messages
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> do_find_or_create_multiple()
  end

  defp do_find_or_create_multiple([]), do: %{}

  defp do_find_or_create_multiple(filtered_error_messages) do
    existing_map =
      __MODULE__
      |> where([te], te.message in ^filtered_error_messages)
      |> select([te], {te.message, te.id})
      |> Repo.all()
      |> Map.new()

    missing_errors = filtered_error_messages -- Map.keys(existing_map)

    now = DateTime.utc_now()
    insert_params = Enum.map(missing_errors, &%{message: &1, inserted_at: now})

    {_total, inserted} =
      Repo.insert_all(__MODULE__, insert_params,
        on_conflict: {:replace, [:inserted_at]},
        conflict_target: [:message],
        returning: true
      )

    new_records_map = Map.new(inserted, &{&1.message, &1.id})

    Map.merge(existing_map, new_records_map)
  end
end
