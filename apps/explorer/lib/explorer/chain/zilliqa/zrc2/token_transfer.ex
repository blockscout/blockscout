defmodule Explorer.Chain.Zilliqa.Zrc2.TokenTransfer.Schema do
  @moduledoc """
    Models ZRC-2 token transfers.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Zilliqa.Zrc2.TokenTransfers
  """
  alias Explorer.Chain.{
    Address,
    Block,
    Hash,
    Transaction
  }

  defmacro generate do
    quote do
      @primary_key false
      typed_schema "zrc2_token_transfers" do
        belongs_to(:transaction, Transaction,
          foreign_key: :transaction_hash,
          primary_key: true,
          references: :hash,
          type: Hash.Full,
          null: false
        )

        field(:log_index, :integer, primary_key: true, null: false)

        belongs_to(:from_address, Address,
          foreign_key: :from_address_hash,
          references: :hash,
          type: Hash.Address,
          null: false
        )

        belongs_to(:to_address, Address,
          foreign_key: :to_address_hash,
          references: :hash,
          type: Hash.Address,
          null: false
        )

        field(:amount, :decimal)

        belongs_to(
          :zrc2_address,
          Address,
          foreign_key: :zrc2_address_hash,
          references: :hash,
          type: Hash.Address,
          null: false
        )

        field(:block_number, :integer) :: Block.block_number()

        belongs_to(:block, Block,
          foreign_key: :block_hash,
          primary_key: true,
          references: :hash,
          type: Hash.Full,
          null: false
        )

        timestamps()
      end
    end
  end
end

defmodule Explorer.Chain.Zilliqa.Zrc2.TokenTransfer do
  @moduledoc """
  Represents a token transfer between addresses for a given ZRC-2 token with unknown ERC-20 adapter contract address yet.
  """

  use Explorer.Schema

  require Explorer.Chain.Zilliqa.Zrc2.TokenTransfer.Schema

  import Ecto.Changeset

  @typedoc """
  * `:transaction_hash` - Transaction foreign key.
  * `:transaction` - The `t:Explorer.Chain.Transaction.t/0` ledger.
  * `:log_index` - Index of the corresponding `t:Explorer.Chain.Log.t/0` in the block.
  * `:from_address_hash` - Address hash foreign key.
  * `:from_address` - The `t:Explorer.Chain.Address.t/0` that sent the tokens.
  * `:to_address_hash` - Address hash foreign key.
  * `:to_address` - The `t:Explorer.Chain.Address.t/0` that received the tokens.
  * `:amount` - The token transferred amount.
  * `:zrc2_address_hash` - Address hash foreign key.
  * `:zrc2_address` - The `t:Explorer.Chain.Address.t/0` of the token's contract.
  * `:block_number` - The block number that the transfer took place in.
  * `:block_hash` - The hash of the block.
  """
  Explorer.Chain.Zilliqa.Zrc2.TokenTransfer.Schema.generate()

  @required_attrs ~w(transaction_hash log_index from_address_hash to_address_hash amount zrc2_address_hash block_number block_hash)a

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = transfer, attrs) do
    transfer
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint([:transaction_hash, :log_index, :block_hash])
  end
end
