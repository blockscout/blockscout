defmodule Explorer.Chain.OptimismWithdrawal do
  @moduledoc "Models Optimism withdrawal."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(msg_nonce withdrawal_hash l2_tx_hash l2_block_number)a

  @type t :: %__MODULE__{
          msg_nonce: Decimal.t(),
          withdrawal_hash: Hash.t(),
          l2_tx_hash: Hash.t(),
          l2_block_number: non_neg_integer()
        }

  @primary_key false
  schema "op_withdrawals" do
    field(:msg_nonce, :decimal, primary_key: true)
    field(:withdrawal_hash, Hash.Full)
    field(:l2_tx_hash, Hash.Full)
    field(:l2_block_number, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = withdrawals, attrs \\ %{}) do
    withdrawals
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
