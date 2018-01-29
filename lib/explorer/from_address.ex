defmodule Explorer.FromAddress do
  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.FromAddress

  @moduledoc false

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @primary_key false
  schema "from_addresses" do
    belongs_to :transaction, Explorer.Transaction, primary_key: true
    belongs_to :address, Explorer.Address
    timestamps()
  end

  def changeset(%FromAddress{} = to_address, attrs \\ %{}) do
    to_address
    |> cast(attrs, [:transaction_id, :address_id])
  end
end
