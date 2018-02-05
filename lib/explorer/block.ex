defmodule Explorer.Block do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Explorer.Block

  @moduledoc false

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "blocks" do
    field :number, :integer
    field :hash, :string
    field :parent_hash, :string
    field :nonce, :string
    field :miner, :string
    field :difficulty, :decimal
    field :total_difficulty, :decimal
    field :size, :integer
    field :gas_limit, :integer
    field :gas_used, :integer
    field :timestamp, Timex.Ecto.DateTime
    timestamps()

    has_many :transactions, Explorer.Transaction
  end

  @required_attrs ~w(number hash parent_hash nonce miner difficulty
                     total_difficulty size gas_limit gas_used timestamp)a
  @optional_attrs ~w()a

  @doc false
  def changeset(%Block{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs, @optional_attrs)
    |> cast_assoc(:transactions)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
  end

  def null do
    %Block{number: -1}
  end

  def latest(query) do
    query |> order_by(desc: :number)
  end
end
