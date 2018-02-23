defmodule Explorer.FromAddress do
  @moduledoc false
  alias Explorer.FromAddress
  import Ecto.Changeset
  use Ecto.Schema

  @timestamps_opts [
    type: Timex.Ecto.DateTime,
    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}
  ]

  @primary_key false
  schema "from_addresses" do
    belongs_to(:transaction, Explorer.Transaction, primary_key: true)
    belongs_to(:address, Explorer.Address)
    timestamps()
  end

  def changeset(%FromAddress{} = to_address, attrs \\ %{}) do
    to_address
    |> cast(attrs, [:transaction_id, :address_id])
    |> unique_constraint(:transaction_id, name: :from_addresses_transaction_id_index)
  end
end
