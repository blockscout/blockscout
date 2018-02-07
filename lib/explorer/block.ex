defmodule Explorer.Block do
  @moduledoc """
    Stores a web3 block.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Explorer.Block
  alias Explorer.BlockTransaction
  alias Explorer.Transaction

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  schema "blocks" do
    has_many :block_transactions, BlockTransaction
    many_to_many :transactions, Transaction, join_through: "block_transactions"

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
  end

  @required_attrs ~w(number hash parent_hash nonce miner difficulty
                     total_difficulty size gas_limit gas_used timestamp)a

  @doc false
  def changeset(%Block{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> update_change(:hash, &String.downcase/1)
    |> unique_constraint(:hash)
    |> cast_assoc(:transactions)
  end

  def null do
    %Block{number: -1}
  end

  def latest(query) do
    query |> order_by(desc: :number)
  end
end
