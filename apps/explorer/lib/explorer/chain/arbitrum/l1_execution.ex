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

  @typedoc """
  Descriptor of the L1 execution transaction related to a L2 to L1 message on Arbitrum rollups:
    * `message_id` - The ID of the message from `Explorer.Chain.Arbitrum.Message`.
                     There could be situations when an execution of a message is
                     discovered, but the message itself is not indexed yet.
    * `execution_id` - The ID of the execution transaction from `Explorer.Chain.Arbitrum.LifecycleTransaction`.
  """
  @type to_import :: %{
          :message_id => non_neg_integer(),
          :execution_id => non_neg_integer()
        }

  @typedoc """
    * `message_id` - The ID of the message from `Explorer.Chain.Arbitrum.Message`.
                     There could be situations when an execution of a message is
                     discovered, but the message itself is not indexed yet.
    * `execution_id` - The ID of the execution transaction from `Explorer.Chain.Arbitrum.LifecycleTransaction`.
    * `execution_transaction` - An instance of `Explorer.Chain.Arbitrum.LifecycleTransaction`
                                referenced by `execution_id`.
  """
  @primary_key {:message_id, :integer, autogenerate: false}
  typed_schema "arbitrum_l1_executions" do
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
