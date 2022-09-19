defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  require Logger

  import Ecto.Query, only: [from: 2, preload: 3, subquery: 1, where: 3]

  alias ABI.FunctionSelector

  alias Ecto.Changeset

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Address,
    Block,
    ContractMethod,
    Data,
    Gas,
    Hash,
    InternalTransaction,
    Log,
    TokenTransfer,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Transaction.{Fork, Status}

  @optional_attrs ~w(max_priority_fee_per_gas max_fee_per_gas block_hash block_number created_contract_address_hash cumulative_gas_used earliest_processing_start
                     error gas_used index created_contract_code_indexed_at status to_address_hash revert_reason type has_error_in_internal_txs cosmos_hash)a

  @required_attrs ~w(from_address_hash gas gas_price hash input nonce r s v value)a

  @typedoc """
  X coordinate module n in
  [Elliptic Curve Digital Signature Algorithm](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
  (EDCSA)
  """
  @type r :: Decimal.t()

  @typedoc """
  Y coordinate module n in
  [Elliptic Curve Digital Signature Algorithm](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
  (EDCSA)
  """
  @type s :: Decimal.t()

  @typedoc """
  The index of the transaction in its block.
  """
  @type transaction_index :: non_neg_integer()

  @typedoc """
  `t:standard_v/0` + `27`

  | `v`  | X      | Y    |
  |------|--------|------|
  | `27` | lower  | even |
  | `28` | lower  | odd  |
  | `29` | higher | even |
  | `30` | higher | odd  |

  **Note: that `29` and `30` are exceedingly rarely, and will in practice only ever be seen in specifically generated
  examples.**
  """
  @type v :: 27..30

  @typedoc """
  How much the sender is willing to pay in wei per unit of gas.
  """
  @type wei_per_gas :: Wei.t()

  @typedoc """
   * `block` - the block in which this transaction was mined/validated.  `nil` when transaction is pending or has only
     been collated into one of the `uncles` in one of the `forks`.
   * `block_hash` - `block` foreign key. `nil` when transaction is pending or has only been collated into one of the
     `uncles` in one of the `forks`.
   * `block_number` - Denormalized `block` `number`. `nil` when transaction is pending or has only been collated into
     one of the `uncles` in one of the `forks`.
   * `created_contract_address` - belongs_to association to `address` corresponding to `created_contract_address_hash`.
   * `created_contract_address_hash` - Denormalized `internal_transaction` `created_contract_address_hash`
     populated only when `to_address_hash` is nil.
   * `cumulative_gas_used` - the cumulative gas used in `transaction`'s `t:Explorer.Chain.Block.t/0` before
     `transaction`'s `index`.  `nil` when transaction is pending
   * `earliest_processing_start` - If the pending transaction fetcher was alive and received this transaction, we can
      be sure that this transaction did not start processing until after the last time we fetched pending transactions,
      so we annotate that with this field. If it is `nil`, that means we don't have a lower bound for when it started
      processing.
   * `error` - the `error` from the last `t:Explorer.Chain.InternalTransaction.t/0` in `internal_transactions` that
     caused `status` to be `:error`.  Only set after `internal_transactions_index_at` is set AND if there was an error.
     Also, `error` is set if transaction is replaced/dropped
   * `forks` - copies of this transactions that were collated into `uncles` not on the primary consensus of the chain.
   * `from_address` - the source of `value`
   * `from_address_hash` - foreign key of `from_address`
   * `gas` - Gas provided by the sender
   * `gas_price` - How much the sender is willing to pay for `gas`
   * `gas_used` - the gas used for just `transaction`.  `nil` when transaction is pending or has only been collated into
     one of the `uncles` in one of the `forks`.
   * `hash` - hash of contents of this transaction
   * `index` - index of this transaction in `block`.  `nil` when transaction is pending or has only been collated into
     one of the `uncles` in one of the `forks`.
   * `input`- data sent along with the transaction
   * `internal_transactions` - transactions (value transfers) created while executing contract used for this
     transaction
   * `created_contract_code_indexed_at` - when created `address` code was fetched by `Indexer`
   * `revert_reason` - revert reason of transaction

     | `status` | `contract_creation_address_hash` | `input`    | Token Transfer? | `internal_transactions_indexed_at`        | `internal_transactions` | Description                                                                                         |
     |----------|----------------------------------|------------|-----------------|-------------------------------------------|-------------------------|-----------------------------------------------------------------------------------------------------|
     | `:ok`    | `nil`                            | Empty      | Don't Care      | `inserted_at`                             | Unfetched               | Simple `value` transfer transaction succeeded.  Internal transactions would be same value transfer. |
     | `:ok`    | `nil`                            | Don't Care | `true`          | `inserted_at`                             | Unfetched               | Token transfer (from `logs`) that didn't happen during a contract creation.                         |
     | `:ok`    | Don't Care                       | Non-Empty  | Don't Care      | When `internal_transactions` are indexed. | Fetched                 | A contract call that succeeded.                                                                     |
     | `:error` | nil                              | Empty      | Don't Care      | When `internal_transactions` are indexed. | Fetched                 | Simple `value` transfer transaction failed. Internal transactions fetched for `error`.              |
     | `:error` | Don't Care                       | Non-Empty  | Don't Care      | When `internal_transactions` are indexed. | Fetched                 | A contract call that failed.                                                                        |
     | `nil`    | Don't Care                       | Don't Care | Don't Care      | When `internal_transactions` are indexed. | Depends                 | A pending post-Byzantium transaction will only know its status from receipt.                        |
     | `nil`    | Don't Care                       | Don't Care | Don't Care      | When `internal_transactions` are indexed. | Fetched                 | A pre-Byzantium transaction requires internal transactions to determine status.                     |
   * `logs` - events that occurred while mining the `transaction`.
   * `nonce` - the number of transaction made by the sender prior to this one
   * `r` - the R field of the signature. The (r, s) is the normal output of an ECDSA signature, where r is computed as
       the X coordinate of a point R, modulo the curve order n.
   * `s` - The S field of the signature.  The (r, s) is the normal output of an ECDSA signature, where r is computed as
       the X coordinate of a point R, modulo the curve order n.
   * `status` - whether the transaction was successfully mined or failed.  `nil` when transaction is pending or has only
     been collated into one of the `uncles` in one of the `forks`.
   * `to_address` - sink of `value`
   * `to_address_hash` - `to_address` foreign key
   * `uncles` - uncle blocks where `forks` were collated
   * `v` - The V field of the signature.
   * `value` - wei transferred from `from_address` to `to_address`
   * `revert_reason` - revert reason of transaction
   * `max_priority_fee_per_gas` - User defined maximum fee (tip) per unit of gas paid to validator for transaction prioritization.
   * `max_fee_per_gas` - Maximum total amount per unit of gas a user is willing to pay for a transaction, including base fee and priority fee.
   * `type` - New transaction type identifier introduced in EIP 2718 (Berlin HF)
   * `has_error_in_internal_txs` - shows if the internal transactions related to transaction have errors
  """
  @type t :: %__MODULE__{
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          block_hash: Hash.t() | nil,
          block_number: Block.block_number() | nil,
          created_contract_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          created_contract_address_hash: Hash.Address.t() | nil,
          created_contract_code_indexed_at: DateTime.t() | nil,
          cumulative_gas_used: Gas.t() | nil,
          earliest_processing_start: DateTime.t() | nil,
          error: String.t() | nil,
          forks: %Ecto.Association.NotLoaded{} | [Fork.t()],
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Address.t(),
          gas: Gas.t(),
          gas_price: wei_per_gas,
          gas_used: Gas.t() | nil,
          hash: Hash.t(),
          cosmos_hash: String.t() | nil,
          index: transaction_index | nil,
          input: Data.t(),
          internal_transactions: %Ecto.Association.NotLoaded{} | [InternalTransaction.t()],
          logs: %Ecto.Association.NotLoaded{} | [Log.t()],
          nonce: non_neg_integer(),
          r: r(),
          s: s(),
          status: Status.t() | nil,
          to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          to_address_hash: Hash.Address.t() | nil,
          uncles: %Ecto.Association.NotLoaded{} | [Block.t()],
          v: v(),
          value: Wei.t(),
          revert_reason: String.t() | nil,
          max_priority_fee_per_gas: wei_per_gas | nil,
          max_fee_per_gas: wei_per_gas | nil,
          type: non_neg_integer() | nil,
          has_error_in_internal_txs: boolean()
        }

  @derive {Poison.Encoder,
           only: [
             :block_number,
             :cumulative_gas_used,
             :error,
             :gas,
             :gas_price,
             :gas_used,
             :hash,
             :cosmos_hash,
             :index,
             :created_contract_code_indexed_at,
             :input,
             :nonce,
             :r,
             :s,
             :v,
             :status,
             :value,
             :revert_reason
           ]}

  @derive {Jason.Encoder,
           only: [
             :block_number,
             :cumulative_gas_used,
             :error,
             :gas,
             :gas_price,
             :gas_used,
             :hash,
             :cosmos_hash,
             :index,
             :created_contract_code_indexed_at,
             :input,
             :nonce,
             :r,
             :s,
             :v,
             :status,
             :value,
             :revert_reason
           ]}

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "transactions" do
    field(:block_number, :integer)
    field(:cumulative_gas_used, :decimal)
    field(:earliest_processing_start, :utc_datetime_usec)
    field(:error, :string)
    field(:gas, :decimal)
    field(:gas_price, Wei)
    field(:gas_used, :decimal)
    field(:cosmos_hash, :string)
    field(:index, :integer)
    field(:created_contract_code_indexed_at, :utc_datetime_usec)
    field(:input, Data)
    field(:nonce, :integer)
    field(:r, :decimal)
    field(:s, :decimal)
    field(:status, Status)
    field(:v, :decimal)
    field(:value, Wei)
    field(:revert_reason, :string)
    field(:max_priority_fee_per_gas, Wei)
    field(:max_fee_per_gas, Wei)
    field(:type, :integer)
    field(:has_error_in_internal_txs, :boolean)

    # A transient field for deriving old block hash during transaction upserts.
    # Used to force refetch of a block in case a transaction is re-collated
    # in a different block. See: https://github.com/blockscout/blockscout/issues/1911
    field(:old_block_hash, Hash.Full)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full)
    has_many(:forks, Fork, foreign_key: :hash)

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address
    )

    has_many(:internal_transactions, InternalTransaction, foreign_key: :transaction_hash)
    has_many(:logs, Log, foreign_key: :transaction_hash)
    has_many(:token_transfers, TokenTransfer, foreign_key: :transaction_hash)

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Address
    )

    has_many(:uncles, through: [:forks, :uncle])

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  @doc """
  A pending transaction does not have a `block_hash`

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  A collated transaction MUST have an `index` so its position in the `block` is known and the `cumulative_gas_used` ane
  `gas_used` to know its fees.

  Post-Byzantium, the status must be present when a block is collated.

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     gas_used: 4600000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     status: :ok,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  But, pre-Byzantium the status cannot be known until the `Explorer.Chain.InternalTransaction` are checked for an
  `error`, so `status` is not required since we can't from the transaction data alone check if the chain is pre- or
  post-Byzantium.

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     gas_used: 4600000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  The `error` can only be set with a specific error message when `status` is `:error`

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
      ...>     error: "Out of gas",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     gas_used: 4600000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      false
      iex> Keyword.get_values(changeset.errors, :error)
      [{"can't be set when status is not :error", []}]

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
      ...>     error: "Out of gas",
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     gas_used: 4600000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     status: :error,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    attrs_to_cast = @required_attrs ++ @optional_attrs

    transaction
    |> cast(attrs, attrs_to_cast)
    |> validate_required(@required_attrs)
    |> validate_collated()
    |> validate_error()
    |> validate_status()
    |> check_collated()
    |> check_error()
    |> check_status()
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:hash)
  end

  def update_error_in_internal_txs(hash) do
    case Hash.Full.cast(hash) do
      {:ok, tx_hash} ->
        schema = Repo.get_by(Transaction, [hash: tx_hash])
        if is_nil(schema) == false and is_nil(schema.has_error_in_internal_txs) do
          change(schema, %{has_error_in_internal_txs: true}) |> Repo.update()
        else
          {:error, nil}
        end
      _ ->
        {:error, nil}
    end
  end

  def preload_token_transfers(query, address_hash) do
    token_transfers_query =
      from(
        tt in TokenTransfer,
        where:
          tt.token_contract_address_hash == ^address_hash or tt.to_address_hash == ^address_hash or
            tt.from_address_hash == ^address_hash,
        order_by: [asc: tt.log_index],
        preload: [:token, [from_address: :names], [to_address: :names]]
      )

    preload(query, [tt], token_transfers: ^token_transfers_query)
  end

  def decoded_revert_reason(transaction, revert_reason) do
    case revert_reason do
      "0x" <> hex_part ->
        process_hex_revert_reason(hex_part, transaction)

      hex_part ->
        process_hex_revert_reason(hex_part, transaction)
    end
  end

  defp process_hex_revert_reason(hex_revert_reason, %__MODULE__{to_address: smart_contract, hash: hash}) do
    case Integer.parse(hex_revert_reason, 16) do
      {number, ""} ->
        binary_revert_reason = :binary.encode_unsigned(number)
        decoded_input_data(%Transaction{to_address: smart_contract, hash: hash, input: %{bytes: binary_revert_reason}})

      _ ->
        hex_revert_reason
    end
  end

  # Because there is no contract association, we know the contract was not verified
  def decoded_input_data(%__MODULE__{to_address: nil}), do: {:error, :no_to_address}
  def decoded_input_data(%__MODULE__{input: %{bytes: bytes}}) when bytes in [nil, <<>>], do: {:error, :no_input_data}
  def decoded_input_data(%__MODULE__{to_address: %{contract_code: nil}}), do: {:error, :not_a_contract_call}

  def decoded_input_data(%__MODULE__{
        to_address: %{smart_contract: nil},
        input: %{bytes: <<method_id::binary-size(4), _::binary>> = data},
        hash: hash
      }) do
    candidates_query =
      from(
        contract_method in ContractMethod,
        where: contract_method.identifier == ^method_id,
        limit: 1
      )

    candidates =
      candidates_query
      |> Repo.all()
      |> Enum.flat_map(fn candidate ->
        case do_decoded_input_data(data, [candidate.abi], nil, hash) do
          {:ok, _, _, _} = decoded -> [decoded]
          _ -> []
        end
      end)

    {:error, :contract_not_verified, candidates}
  end

  def decoded_input_data(%__MODULE__{to_address: %{smart_contract: nil}}) do
    {:error, :contract_not_verified, []}
  end

  def decoded_input_data(%__MODULE__{
        input: %{bytes: data},
        to_address: %{smart_contract: %{abi: abi, address_hash: address_hash}},
        hash: hash
      }) do
    case do_decoded_input_data(data, abi, address_hash, hash) do
      # In some cases transactions use methods of some unpredictadle contracts, so we can try to look up for method in a whole DB
      {:error, :could_not_decode} ->
        case decoded_input_data(%__MODULE__{
               to_address: %{smart_contract: nil},
               input: %{bytes: data},
               hash: hash
             }) do
          {:error, :contract_not_verified, []} ->
            {:error, :could_not_decode}

          {:error, :contract_not_verified, candidates} ->
            {:error, :contract_verified, candidates}

          _ ->
            {:error, :could_not_decode}
        end

      output ->
        output
    end
  end

  defp do_decoded_input_data(data, abi, address_hash, hash) do
    full_abi = Chain.combine_proxy_implementation_abi(address_hash, abi)

    with {:ok, {selector, values}} <- find_and_decode(full_abi, data, hash),
         {:ok, mapping} <- selector_mapping(selector, values, hash),
         identifier <- Base.encode16(selector.method_id, case: :lower),
         text <- function_call(selector.function, mapping),
         do: {:ok, identifier, text, mapping}
  end

  def get_method_name(
        %__MODULE__{
          input: %{bytes: <<method_id::binary-size(4), _::binary>>}
        } = transaction
      ) do
    if transaction.created_contract_address_hash do
      nil
    else
      case Transaction.decoded_input_data(%__MODULE__{
             to_address: %{smart_contract: nil},
             input: transaction.input,
             hash: transaction.hash
           }) do
        {:error, :contract_not_verified, [{:ok, _method_id, decoded_func, _}]} ->
          parse_method_name(decoded_func)

        {:error, :contract_not_verified, []} ->
          "0x" <> Base.encode16(method_id, case: :lower)

        _ ->
          "Transfer"
      end
    end
  end

  def get_method_name(_), do: "Transfer"

  defp parse_method_name(method_desc) do
    method_desc
    |> String.split("(")
    |> Enum.at(0)
    |> upcase_first
  end

  defp upcase_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  defp function_call(name, mapping) do
    text =
      mapping
      |> Stream.map(fn {name, type, _} -> [type, " ", name] end)
      |> Enum.intersperse(", ")

    IO.iodata_to_binary([name, "(", text, ")"])
  end

  defp find_and_decode(abi, data, hash) do
    result =
      abi
      |> ABI.parse_specification()
      |> ABI.find_and_decode(data)

    {:ok, result}
  rescue
    _ ->
      Logger.warn(fn -> ["Could not decode input data for transaction: ", Hash.to_iodata(hash)] end)
      {:error, :could_not_decode}
  end

  defp selector_mapping(selector, values, hash) do
    types = Enum.map(selector.types, &FunctionSelector.encode_type/1)

    mapping = Enum.zip([selector.input_names, types, values])

    {:ok, mapping}
  rescue
    _ ->
      Logger.warn(fn -> ["Could not decode input data for transaction: ", Hash.to_iodata(hash)] end)
      {:error, :could_not_decode}
  end

  @doc """
  Produces a list of queries starting from the given one and adding filters for
  transactions that are linked to the given address_hash through a direction.
  """
  def matching_address_queries_list(query, :from, address_hash) do
    [where(query, [t], t.from_address_hash == ^address_hash)]
  end

  def matching_address_queries_list(query, :to, address_hash) do
    [
      where(query, [t], t.to_address_hash == ^address_hash),
      where(query, [t], t.created_contract_address_hash == ^address_hash)
    ]
  end

  def matching_address_queries_list(query, _direction, address_hash) do
    [
      where(query, [t], t.from_address_hash == ^address_hash),
      where(query, [t], t.to_address_hash == ^address_hash),
      where(query, [t], t.created_contract_address_hash == ^address_hash)
    ]
  end

  def not_pending_transactions(query) do
    where(query, [t], not is_nil(t.block_number))
  end

  def not_dropped_or_replaced_transactions(query) do
    where(query, [t], is_nil(t.error) or t.error != "dropped/replaced")
  end

  @collated_fields ~w(block_number cumulative_gas_used gas_used index)a

  @collated_message "can't be blank when the transaction is collated into a block"
  @collated_field_to_check Enum.into(@collated_fields, %{}, fn collated_field ->
                             {collated_field, :"collated_#{collated_field}}"}
                           end)

  defp check_collated(%Changeset{} = changeset) do
    check_constraints(changeset, @collated_field_to_check, @collated_message)
  end

  @error_message "can't be set when status is not :error"

  defp check_error(%Changeset{} = changeset) do
    check_constraint(changeset, :error, message: @error_message, name: :error)
  end

  @status_message "can't be set when the block_hash is unknown"

  defp check_status(%Changeset{} = changeset) do
    check_constraint(changeset, :status, message: @status_message, name: :status)
  end

  defp check_constraints(%Changeset{} = changeset, field_to_name, message)
       when is_map(field_to_name) and is_binary(message) do
    Enum.reduce(field_to_name, changeset, fn {field, name}, acc_changeset ->
      check_constraint(
        acc_changeset,
        field,
        message: message,
        name: name
      )
    end)
  end

  defp validate_collated(%Changeset{} = changeset) do
    case Changeset.get_field(changeset, :block_hash) do
      %Hash{} -> Enum.reduce(@collated_fields, changeset, &validate_collated/2)
      nil -> changeset
    end
  end

  defp validate_collated(field, %Changeset{} = changeset) when is_atom(field) do
    case Changeset.get_field(changeset, field) do
      nil -> Changeset.add_error(changeset, field, @collated_message)
      _ -> changeset
    end
  end

  defp validate_error(%Changeset{} = changeset) do
    if Changeset.get_field(changeset, :status) != :error and Changeset.get_field(changeset, :error) != nil do
      Changeset.add_error(changeset, :error, @error_message)
    else
      changeset
    end
  end

  defp validate_status(%Changeset{} = changeset) do
    if Changeset.get_field(changeset, :block_hash) == nil and
         Changeset.get_field(changeset, :status) != nil do
      Changeset.add_error(changeset, :status, @status_message)
    else
      changeset
    end
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions with token transfers from the give address hash.

  The results will be ordered by block number and index DESC.
  """
  def transactions_with_token_transfers(address_hash, token_hash) do
    query = transactions_with_token_transfers_query(address_hash, token_hash)

    from(
      t in subquery(query),
      order_by: [desc: t.block_number, desc: t.index],
      preload: [:from_address, :to_address, :created_contract_address, :block]
    )
  end

  defp transactions_with_token_transfers_query(address_hash, token_hash) do
    from(
      t in Transaction,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.token_contract_address_hash == ^token_hash,
      where: tt.from_address_hash == ^address_hash or tt.to_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  def transactions_with_token_transfers_direction(direction, address_hash) do
    query = transactions_with_token_transfers_query_direction(direction, address_hash)

    from(
      t in subquery(query),
      order_by: [desc: t.block_number, desc: t.index],
      preload: [:from_address, :to_address, :created_contract_address, :block]
    )
  end

  defp transactions_with_token_transfers_query_direction(:from, address_hash) do
    from(
      t in Transaction,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.from_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  defp transactions_with_token_transfers_query_direction(:to, address_hash) do
    from(
      t in Transaction,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.to_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  defp transactions_with_token_transfers_query_direction(_, address_hash) do
    from(
      t in Transaction,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.from_address_hash == ^address_hash or tt.to_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions with the specified block_number
  """
  def transactions_with_block_number(block_number) do
    from(
      t in Transaction,
      where: t.block_number == ^block_number
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch the last nonce from the given address hash.

  The last nonce value means the total of transactions that the given address has sent through the
  chain. Also, the query uses the last `block_number` to get the last nonce because this column is
  indexed in DB, then the query is faster than ordering by last nonce.
  """
  def last_nonce_by_address_query(address_hash) do
    from(
      t in Transaction,
      select: t.nonce,
      where: t.from_address_hash == ^address_hash,
      order_by: [desc: :block_number],
      limit: 1
    )
  end
end
