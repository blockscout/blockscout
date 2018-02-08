defmodule Explorer.ToAddress do
  @moduledoc false
  alias Explorer.ToAddress
  import Ecto.Changeset
  use Ecto.Schema

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @primary_key false
  schema "to_addresses" do
    belongs_to :transaction, Explorer.Transaction, primary_key: true
    belongs_to :address, Explorer.Address
    timestamps()
  end

  def changeset(%ToAddress{} = to_address, attrs \\ %{}) do
    to_address
    |> cast(attrs, [:transaction_id, :address_id])
    |> unique_constraint(:transaction_id,
      name: :to_addresses_transaction_id_index)
  end
end
