defmodule Explorer.Chain.FheOperation do
  @moduledoc """
  Represents a single FHE (Fully Homomorphic Encryption) operation within a transaction.
  FHE operations are parsed from transaction logs during block indexing.
  """

  use Explorer.Schema

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.{Block, Hash, Transaction}
  alias Explorer.Repo

  @primary_key false
  typed_schema "fhe_operations" do
    # Composite primary key
    field(:log_index, :integer, primary_key: true, null: false)

    # Foreign keys
    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    # Operation details
    field(:operation, :string, null: false)
    field(:operation_type, :string, null: false)
    field(:fhe_type, :string, null: false)
    field(:is_scalar, :boolean, null: false)

    # HCU metrics
    field(:hcu_cost, :integer, null: false)
    field(:hcu_depth, :integer, null: false)

    # Addresses and handles
    field(:caller, Hash.Address)
    field(:result_handle, :binary, null: false)
    field(:input_handles, :map)

    # Metadata
    field(:block_number, :integer, null: false)

    timestamps()
  end

  @required_attrs ~w(transaction_hash log_index block_hash block_number operation operation_type fhe_type is_scalar hcu_cost hcu_depth result_handle)a
  @optional_attrs ~w(caller input_handles)a

  @doc false
  def changeset(fhe_operation, attrs) do
    fhe_operation
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
  Returns all FHE operations for a given transaction hash, ordered by log_index.
  """
  @spec by_transaction_hash(Hash.Full.t()) :: [t()]
  def by_transaction_hash(transaction_hash) do
    query =
      from(
        op in __MODULE__,
        where: op.transaction_hash == ^transaction_hash,
        order_by: [asc: op.log_index]
      )

    Repo.all(query)
  end

  @doc """
  Returns transaction-level metrics for a given transaction.
  Returns a map with operation_count, total_hcu, and max_depth_hcu.
  """
  @spec transaction_metrics(Hash.Full.t()) :: %{
          operation_count: non_neg_integer(),
          total_hcu: non_neg_integer(),
          max_depth_hcu: non_neg_integer()
        }
  def transaction_metrics(transaction_hash) do
    query =
      from(
        op in __MODULE__,
        where: op.transaction_hash == ^transaction_hash,
        select: %{
          operation_count: count(op.log_index),
          total_hcu: coalesce(sum(op.hcu_cost), 0),
          max_depth_hcu: coalesce(max(op.hcu_depth), 0)
        }
      )

    Repo.one(query) || %{operation_count: 0, total_hcu: 0, max_depth_hcu: 0}
  end

  @doc """
  Returns all unique FHE contract addresses (callers) ordered by total HCU usage.
  """
  @spec top_fhe_callers(non_neg_integer()) :: [
          %{caller: Hash.Address.t(), total_hcu: non_neg_integer(), operation_count: non_neg_integer()}
        ]
  def top_fhe_callers(limit \\ 10) do
    query =
      from(
        op in __MODULE__,
        where: not is_nil(op.caller),
        group_by: op.caller,
        select: %{
          caller: op.caller,
          total_hcu: sum(op.hcu_cost),
          operation_count: count(op.log_index)
        },
        order_by: [desc: sum(op.hcu_cost)],
        limit: ^limit
      )

    Repo.all(query)
  end

  @doc """
  Returns operation distribution statistics.
  """
  @spec operation_stats() :: [%{operation: String.t(), operation_type: String.t(), count: non_neg_integer()}]
  def operation_stats do
    query =
      from(
        op in __MODULE__,
        group_by: [op.operation, op.operation_type],
        select: %{
          operation: op.operation,
          operation_type: op.operation_type,
          count: count(op.log_index)
        },
        order_by: [desc: count(op.log_index)]
      )

    Repo.all(query)
  end
end
