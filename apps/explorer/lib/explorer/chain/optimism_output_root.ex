defmodule Explorer.Chain.OptimismOutputRoot do
  @moduledoc "Models an output root for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(l2_output_index l2_block_number l1_transaction_hash l1_timestamp l1_block_number output_root)a

  @type t :: %__MODULE__{
          l2_output_index: non_neg_integer(),
          l2_block_number: non_neg_integer(),
          l1_transaction_hash: Hash.t(),
          l1_timestamp: DateTime.t(),
          l1_block_number: non_neg_integer(),
          output_root: Hash.t()
        }

  @primary_key false
  schema "op_output_roots" do
    field(:l2_output_index, :integer, primary_key: true)
    field(:l2_block_number, :integer)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_block_number, :integer)
    field(:output_root, Hash.Full)

    timestamps()
  end

  def changeset(%__MODULE__{} = output_roots, attrs \\ %{}) do
    output_roots
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
