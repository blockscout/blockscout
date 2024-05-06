defmodule Explorer.Chain.Arbitrum.L1Execution do
  @moduledoc """
    Models a list of execution transactions related to a L2 to L1 messages on Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.L1Executions

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Arbitrum.LifecycleTransaction

  @required_attrs ~w(message_id execution_id)a

  @type t :: %__MODULE__{
          message_id: non_neg_integer(),
          execution_id: non_neg_integer(),
          execution_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil
        }

  @primary_key {:message_id, :integer, autogenerate: false}
  schema "arbitrum_l1_executions" do
    belongs_to(:execution_transaction, LifecycleTransaction,
      foreign_key: :execution_id,
      references: :id,
      type: :integer
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = items, attrs \\ %{}) do
    items
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:execution_id)
    |> unique_constraint(:message_id)
  end
end
