defmodule Explorer.Chain.CeloPendingEpochOperation do
  @moduledoc """
  Tracks epoch blocks that have pending operations.
  """

  use Explorer.Schema

  alias Explorer.Repo

  import Ecto.Query,
    only: [
      from: 2
    ]

  @required_attrs ~w(block_number fetch_epoch_data)a

  @typedoc """
   * `block_number` - the number of the epoch block that has pending operations.
   * `fetch_epoch_data` - if rewards should be fetched (or not)
  """
  @type t :: %__MODULE__{
          block_number: non_neg_integer(),
          fetch_epoch_data: boolean()
        }

  @primary_key {:block_number, :integer, autogenerate: false}
  schema "celo_pending_epoch_operations" do
    field(:fetch_epoch_data, :boolean)

    timestamps()
  end

  def changeset(%__MODULE__{} = celo_epoch_pending_ops, attrs) do
    celo_epoch_pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:block_number, name: :celo_pending_epoch_operations_pkey)
  end

  def default_on_conflict do
    from(
      celo_epoch_pending_ops in __MODULE__,
      update: [
        set: [
          fetch_epoch_data: celo_epoch_pending_ops.fetch_epoch_data or fragment("EXCLUDED.fetch_epoch_data"),
          # Don't update `block_number` as it is used for the conflict target
          inserted_at: celo_epoch_pending_ops.inserted_at,
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ],
      where: fragment("EXCLUDED.fetch_epoch_data <> ?", celo_epoch_pending_ops.fetch_epoch_data)
    )
  end

  @spec delete_celo_pending_epoch_operation(non_neg_integer()) :: __MODULE__.t()
  def delete_celo_pending_epoch_operation(block_number) do
    query = from(cpeo in __MODULE__, where: cpeo.block_number == ^block_number)

    Repo.delete_all(query)
  end
end
