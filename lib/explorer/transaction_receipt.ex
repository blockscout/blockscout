defmodule Explorer.TransactionReceipt do
  @moduledoc "Captures a Web3 Transaction Receipt."

  use Ecto.Schema

  import Ecto.Changeset

  alias Explorer.Transaction
  alias Explorer.TransactionReceipt

  @timestamps_opts [type: Timex.Ecto.DateTime,
                    autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}]

  @required_attrs ~w(cumulative_gas_used gas_used status index)a

  schema "transaction_receipts" do
    belongs_to :transaction, Transaction
    field :cumulative_gas_used, :decimal
    field :gas_used, :decimal
    field :status, :integer
    field :index, :integer
    timestamps()
  end

  def changeset(%TransactionReceipt{} = transaction_receipt, attrs \\ %{}) do
    transaction_receipt
    |> cast(attrs, [:transaction_id | @required_attrs])
    |> cast_assoc(:transaction)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_id)
    |> unique_constraint(:transaction_id)
  end

  def null, do: %TransactionReceipt{}
end
