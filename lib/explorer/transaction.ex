defmodule Explorer.Transaction do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Transaction

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "transactions" do
    field :hash, :string
    timestamps()

    belongs_to :block, Explorer.Block
  end

  @required_attrs ~w(hash)a
  @optional_attrs ~w()a

  @doc false
  def changeset(%Transaction{} = transaction, attrs \\ :empty) do
    transaction
    |> cast(attrs, [:block_id | @required_attrs], @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_id)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
