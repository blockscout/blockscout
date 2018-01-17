defmodule Explorer.Transaction do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Transaction

  schema "transactions" do
    field :hash, :string
    timestamps()

    belongs_to :block, Explorer.Block
  end

  @doc false
  def changeset(%Transaction{} = block, attrs) do
    block
    |> cast(attrs, [:block_id, :hash])
    |> validate_required([:block_id, :hash])
    |> foreign_key_constraint(:block_id)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
