defmodule Explorer.Transaction do
  @moduledoc false
  alias Explorer.BlockTransaction
  alias Explorer.Transaction
  import Ecto.Changeset
  use Ecto.Schema

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "transactions" do
    has_one :block_transaction, BlockTransaction
    has_one :block, through: [:block_transaction, :block]
    field :hash, :string
    field :value, :decimal
    field :gas, :decimal
    field :gas_price, :decimal
    field :input, :string
    field :nonce, :integer
    field :public_key, :string
    field :r, :string
    field :s, :string
    field :standard_v, :string
    field :transaction_index, :string
    field :v, :string
    timestamps()
  end

  @required_attrs ~w(hash value gas gas_price input nonce public_key r s
    standard_v transaction_index v)a
  @optional_attrs ~w()a

  @doc false
  def changeset(%Transaction{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_id)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
