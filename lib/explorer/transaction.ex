defmodule Explorer.Transaction do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Explorer.Transaction

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "transactions" do
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

    belongs_to :block, Explorer.Block

    many_to_many :to_address, Explorer.Address, join_through: "to_addresses", unique: true
  end

  @required_attrs ~w(hash value gas gas_price input nonce public_key r s
    standard_v transaction_index v)a
  @optional_attrs ~w()a

  @doc false
  def changeset(%Transaction{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, [:block_id | @required_attrs], @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_id)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end
end
