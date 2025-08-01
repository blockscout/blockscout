defmodule Explorer.Chain.Neon.LinkedSolanaTransactions do
  @moduledoc """
  A relation table  between a regular EVM transaction and multiple Solana transactions
  """
  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}

  @required_attrs ~w(neon_transaction_hash solana_transaction_hash)a

  @primary_key false
  typed_schema "neon_linked_solana_transactions" do
    field(:neon_transaction_hash, :binary)
    field(:solana_transaction_hash, :string)

    belongs_to(:transaction, Transaction,
      foreign_key: :neon_transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      define_field: false
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:neon_transaction_hash,
      name: "neon_linked_solana_transactions_neon_transaction_hash_fkey"
    )
    |> unique_constraint(:solana_transaction_hash, name: "neon_linked_solana_transactions_hash_index")
  end
end
