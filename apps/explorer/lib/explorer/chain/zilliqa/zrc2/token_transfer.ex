defmodule Explorer.Chain.Zilliqa.Zrc2.TokenTransfer do
  @moduledoc """
  Represents a token transfer between addresses for a given ZRC-2 token with unknown ERC-20 adapter contract address yet.

  Changes in the schema should be reflected in the bulk import module:
  - Explorer.Chain.Import.Runner.Zilliqa.Zrc2.TokenTransfers
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Address, Block, Data, Hash, Log, Transaction}
  alias Explorer.Chain.Zilliqa.Zrc2.TokenAdapter
  alias Explorer.Repo

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
  @primary_key false
  typed_schema "zilliqa_zrc2_token_transfers" do
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

    field(:block_number, :integer)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @required_attrs ~w(transaction_hash log_index from_address_hash to_address_hash amount zrc2_address_hash block_number block_hash)a

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = transfer, attrs) do
    transfer
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
    |> unique_constraint([:transaction_hash, :log_index, :block_hash])
  end

  @doc """
  Gets all transfer logs from the `logs` table for the given block.
  This function is only used by the historic handler.

  ## Parameters
  - `block_number`: The block number.
  - `transfer_events`: The list of transfer logs (their signatures) needed to be found.

  ## Returns
  - A list of found log maps for the given block.
    Each returned log can have the corresponding non-empty `adapter_address_hash` field.
  """
  @spec read_block_logs(non_neg_integer(), [String.t()]) :: [
          %{
            first_topic: Hash.t(),
            data: Data.t(),
            address_hash: Hash.t(),
            transaction_hash: Hash.t(),
            index: non_neg_integer(),
            block_number: non_neg_integer(),
            block_hash: Hash.t(),
            adapter_address_hash: Hash.t() | nil
          }
        ]
  def read_block_logs(block_number, transfer_events) do
    Repo.all(
      from(
        l in Log,
        inner_join: b in Block,
        on: b.hash == l.block_hash and b.consensus == true,
        left_join: a in TokenAdapter,
        on: a.zrc2_address_hash == l.address_hash,
        where: l.block_number == ^block_number and l.first_topic in ^transfer_events,
        select: %{
          first_topic: l.first_topic,
          data: l.data,
          address_hash: l.address_hash,
          transaction_hash: l.transaction_hash,
          index: l.index,
          block_number: l.block_number,
          block_hash: l.block_hash,
          adapter_address_hash: a.adapter_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @doc """
  Gets a list of transactions with necessary data (such as transaction hash, input, and `to` address hash)
  by the list of logs prepared with the `read_block_logs` function. This function is only used by the
  historic handler.

  We only need the transactions having the `TransferSuccess` event with unknown ZRC-2 adapter address.

  ## Parameters
  - `logs`: The list of logs.
  - `zrc2_transfer_success_event`: The signature of the `TransferSuccess` event.

  ## Returns
  - A list of transaction maps for the given list of logs.
  """
  @spec read_transfer_transactions(
          [%{first_topic: Hash.t(), transaction_hash: Hash.t(), adapter_address_hash: Hash.t() | nil}],
          String.t()
        ) :: [%{hash: Hash.t(), input: Data.t(), to_address_hash: Hash.t()}]
  def read_transfer_transactions(logs, zrc2_transfer_success_event) do
    transaction_hashes =
      logs
      |> Enum.filter(
        &(Hash.to_string(&1.first_topic) == zrc2_transfer_success_event and is_nil(&1.adapter_address_hash))
      )
      |> Enum.map(& &1.transaction_hash)

    Repo.all(
      from(
        t in Transaction,
        where: t.hash in ^transaction_hashes,
        select: %{
          hash: t.hash,
          input: t.input,
          to_address_hash: t.to_address_hash
        }
      ),
      timeout: :infinity
    )
  end

  @doc """
  Scans the `zilliqa_zrc2_token_transfers` table for the rows that have corresponding
  adapter addresses in the `zilliqa_zrc2_token_adapters` table and returns the found rows.

  ## Returns
  - The list of found rows. The list can be empty.
  """
  @spec zrc2_token_transfers_having_adapter() :: [
          %{
            transaction_hash: Hash.t(),
            log_index: non_neg_integer(),
            from_address_hash: Hash.t(),
            to_address_hash: Hash.t(),
            amount: Decimal.t(),
            adapter_address_hash: Hash.t(),
            block_number: non_neg_integer(),
            block_hash: Hash.t()
          }
        ]
  def zrc2_token_transfers_having_adapter do
    query =
      from(
        ztt in __MODULE__,
        inner_join: a in TokenAdapter,
        on: a.zrc2_address_hash == ztt.zrc2_address_hash,
        select: %{
          transaction_hash: ztt.transaction_hash,
          log_index: ztt.log_index,
          from_address_hash: ztt.from_address_hash,
          to_address_hash: ztt.to_address_hash,
          amount: ztt.amount,
          adapter_address_hash: a.adapter_address_hash,
          block_number: ztt.block_number,
          block_hash: ztt.block_hash
        }
      )

    query
    |> Repo.all(timeout: :infinity)
  end
end
