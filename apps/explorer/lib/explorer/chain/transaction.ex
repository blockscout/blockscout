defmodule Explorer.Chain.Transaction.Schema do
  @moduledoc """
    Models transactions.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Transactions
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain

  alias Explorer.Chain.{
    Address,
    Beacon.BlobTransaction,
    Block,
    Data,
    Hash,
    InternalTransaction,
    Log,
    PendingTransactionOperation,
    SignedAuthorization,
    TokenTransfer,
    TransactionAction,
    Wei
  }

  alias Explorer.Chain.Arbitrum.BatchBlock, as: ArbitrumBatchBlock
  alias Explorer.Chain.Arbitrum.BatchTransaction, as: ArbitrumBatchTransaction
  alias Explorer.Chain.Arbitrum.Message, as: ArbitrumMessage
  alias Explorer.Chain.PolygonZkevm.BatchTransaction, as: ZkevmBatchTransaction
  alias Explorer.Chain.Transaction.{Fork, Status}
  alias Explorer.Chain.ZkSync.BatchTransaction, as: ZkSyncBatchTransaction

  @chain_type_fields (case @chain_type do
                        :ethereum ->
                          # elem(quote do ... end, 2) doesn't work with a single has_one instruction
                          quote do
                            [
                              has_one(:beacon_blob_transaction, BlobTransaction, foreign_key: :hash, references: :hash)
                            ]
                          end

                        :optimism ->
                          elem(
                            quote do
                              field(:l1_fee, Wei)
                              field(:l1_fee_scalar, :decimal)
                              field(:l1_gas_price, Wei)
                              field(:l1_gas_used, :decimal)
                              field(:l1_transaction_origin, Hash.Full)
                              field(:l1_block_number, :integer)
                            end,
                            2
                          )

                        :scroll ->
                          elem(
                            quote do
                              field(:l1_fee, Wei)
                              field(:queue_index, :integer)
                            end,
                            2
                          )

                        :suave ->
                          elem(
                            quote do
                              belongs_to(
                                :execution_node,
                                Address,
                                foreign_key: :execution_node_hash,
                                references: :hash,
                                type: Hash.Address
                              )

                              field(:wrapped_type, :integer)
                              field(:wrapped_nonce, :integer)
                              field(:wrapped_gas, :decimal)
                              field(:wrapped_gas_price, Wei)
                              field(:wrapped_max_priority_fee_per_gas, Wei)
                              field(:wrapped_max_fee_per_gas, Wei)
                              field(:wrapped_value, Wei)
                              field(:wrapped_input, Data)
                              field(:wrapped_v, :decimal)
                              field(:wrapped_r, :decimal)
                              field(:wrapped_s, :decimal)
                              field(:wrapped_hash, Hash.Full)

                              belongs_to(
                                :wrapped_to_address,
                                Address,
                                foreign_key: :wrapped_to_address_hash,
                                references: :hash,
                                type: Hash.Address
                              )
                            end,
                            2
                          )

                        :polygon_zkevm ->
                          elem(
                            quote do
                              has_one(:zkevm_batch_transaction, ZkevmBatchTransaction,
                                foreign_key: :hash,
                                references: :hash
                              )

                              has_one(:zkevm_batch, through: [:zkevm_batch_transaction, :batch], references: :hash)

                              has_one(:zkevm_sequence_transaction,
                                through: [:zkevm_batch, :sequence_transaction],
                                references: :hash
                              )

                              has_one(:zkevm_verify_transaction,
                                through: [:zkevm_batch, :verify_transaction],
                                references: :hash
                              )
                            end,
                            2
                          )

                        :zksync ->
                          elem(
                            quote do
                              has_one(:zksync_batch_transaction, ZkSyncBatchTransaction,
                                foreign_key: :transaction_hash,
                                references: :hash
                              )

                              has_one(:zksync_batch, through: [:zksync_batch_transaction, :batch])
                              has_one(:zksync_commit_transaction, through: [:zksync_batch, :commit_transaction])
                              has_one(:zksync_prove_transaction, through: [:zksync_batch, :prove_transaction])
                              has_one(:zksync_execute_transaction, through: [:zksync_batch, :execute_transaction])
                            end,
                            2
                          )

                        :celo ->
                          elem(
                            quote do
                              field(:gateway_fee, Wei)

                              belongs_to(:gas_fee_recipient, Address,
                                foreign_key: :gas_fee_recipient_address_hash,
                                references: :hash,
                                type: Hash.Address
                              )

                              belongs_to(:gas_token_contract_address, Address,
                                foreign_key: :gas_token_contract_address_hash,
                                references: :hash,
                                type: Hash.Address
                              )

                              has_one(:gas_token, through: [:gas_token_contract_address, :token])
                            end,
                            2
                          )

                        :arbitrum ->
                          elem(
                            quote do
                              field(:gas_used_for_l1, :decimal)

                              has_one(:arbitrum_batch_transaction, ArbitrumBatchTransaction,
                                foreign_key: :transaction_hash,
                                references: :hash
                              )

                              has_one(:arbitrum_batch, through: [:arbitrum_batch_transaction, :batch])

                              has_one(:arbitrum_commitment_transaction,
                                through: [:arbitrum_batch, :commitment_transaction]
                              )

                              has_one(:arbitrum_batch_block, ArbitrumBatchBlock,
                                foreign_key: :block_number,
                                references: :block_number
                              )

                              has_one(:arbitrum_confirmation_transaction,
                                through: [:arbitrum_batch_block, :confirmation_transaction]
                              )

                              has_one(:arbitrum_message_to_l2, ArbitrumMessage,
                                foreign_key: :completion_transaction_hash,
                                references: :hash
                              )

                              has_one(:arbitrum_message_from_l2, ArbitrumMessage,
                                foreign_key: :originating_transaction_hash,
                                references: :hash
                              )
                            end,
                            2
                          )

                        _ ->
                          []
                      end)

  defmacro generate do
    quote do
      @primary_key false
      typed_schema "transactions" do
        field(:hash, Hash.Full, primary_key: true)
        field(:block_number, :integer)
        field(:block_consensus, :boolean)
        field(:block_timestamp, :utc_datetime_usec)
        field(:cumulative_gas_used, :decimal)
        field(:earliest_processing_start, :utc_datetime_usec)
        field(:error, :string)
        field(:gas, :decimal)
        field(:gas_price, Wei)
        field(:gas_used, :decimal)
        field(:index, :integer)
        field(:created_contract_code_indexed_at, :utc_datetime_usec)
        field(:input, Data)
        field(:nonce, :integer) :: non_neg_integer() | nil
        field(:r, :decimal)
        field(:s, :decimal)
        field(:status, Status)
        field(:v, :decimal)
        field(:value, Wei)
        # TODO change to Data.t(), convert current hex-string values, prune all non-hex ones
        field(:revert_reason, :string)
        field(:max_priority_fee_per_gas, Wei)
        field(:max_fee_per_gas, Wei)
        field(:type, :integer)
        field(:has_error_in_internal_transactions, :boolean)
        field(:has_token_transfers, :boolean, virtual: true)

        # stability virtual fields
        field(:transaction_fee_log, :any, virtual: true)
        field(:transaction_fee_token, :any, virtual: true)

        # A transient field for deriving old block hash during transaction upserts.
        # Used to force refetch of a block in case a transaction is re-collated
        # in a different block. See: https://github.com/blockscout/blockscout/issues/1911
        field(:old_block_hash, Hash.Full)

        timestamps()

        belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full)
        has_many(:forks, Fork, foreign_key: :hash, references: :hash)

        belongs_to(
          :from_address,
          Address,
          foreign_key: :from_address_hash,
          references: :hash,
          type: Hash.Address
        )

        has_many(:internal_transactions, InternalTransaction, foreign_key: :transaction_hash, references: :hash)
        has_many(:logs, Log, foreign_key: :transaction_hash, references: :hash)

        has_many(:token_transfers, TokenTransfer, foreign_key: :transaction_hash, references: :hash)

        has_many(:transaction_actions, TransactionAction,
          foreign_key: :hash,
          preload_order: [asc: :log_index],
          references: :hash
        )

        belongs_to(
          :to_address,
          Address,
          foreign_key: :to_address_hash,
          references: :hash,
          type: Hash.Address
        )

        has_many(:uncles, through: [:forks, :uncle], references: :hash)

        belongs_to(
          :created_contract_address,
          Address,
          foreign_key: :created_contract_address_hash,
          references: :hash,
          type: Hash.Address
        )

        has_many(:signed_authorizations, SignedAuthorization,
          foreign_key: :transaction_hash,
          references: :hash
        )

        has_one(:pending_operation, PendingTransactionOperation, foreign_key: :transaction_hash, references: :hash)

        unquote_splicing(@chain_type_fields)
      end
    end
  end
end

defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    decode_not_a_contract_calls: [:explorer, :decode_not_a_contract_calls]

  require Logger
  require Explorer.Chain.Transaction.Schema

  alias ABI.FunctionSelector
  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Explorer.{Chain, Helper, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Address,
    Block,
    Block.Reward,
    ContractMethod,
    Data,
    DenormalizationHelper,
    Hash,
    SmartContract.Proxy,
    TokenTransfer,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Block.Reader.General, as: BlockReaderGeneral

  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  alias Explorer.Helper, as: ExplorerHelper

  alias Explorer.SmartContract.SigProviderInterface

  @optional_attrs ~w(max_priority_fee_per_gas max_fee_per_gas block_hash block_number
                     block_consensus block_timestamp created_contract_address_hash
                     cumulative_gas_used earliest_processing_start error gas_price
                     gas_used index created_contract_code_indexed_at status
                     to_address_hash revert_reason type has_error_in_internal_transactions r s v)a

  @chain_type_optional_attrs (case @chain_type do
                                :optimism ->
                                  ~w(l1_fee l1_fee_scalar l1_gas_price l1_gas_used l1_transaction_origin l1_block_number)a

                                :scroll ->
                                  ~w(l1_fee queue_index)a

                                :suave ->
                                  ~w(execution_node_hash wrapped_type wrapped_nonce wrapped_to_address_hash wrapped_gas wrapped_gas_price wrapped_max_priority_fee_per_gas wrapped_max_fee_per_gas wrapped_value wrapped_input wrapped_v wrapped_r wrapped_s wrapped_hash)a

                                :arbitrum ->
                                  ~w(gas_used_for_l1)a

                                :celo ->
                                  ~w(gateway_fee gas_fee_recipient_address_hash gas_token_contract_address_hash)a

                                _ ->
                                  ~w()a
                              end)

  @required_attrs ~w(from_address_hash gas hash input nonce value)a

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

  @derive {Poison.Encoder,
           only: [
             :block_number,
             :block_timestamp,
             :cumulative_gas_used,
             :error,
             :gas,
             :gas_price,
             :gas_used,
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
             :block_timestamp,
             :cumulative_gas_used,
             :error,
             :gas,
             :gas_price,
             :gas_used,
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

  @typedoc """
   * `block` - the block in which this transaction was mined/validated.  `nil` when transaction is pending or has only
     been collated into one of the `uncles` in one of the `forks`.
   * `block_hash` - `block` foreign key. `nil` when transaction is pending or has only been collated into one of the
     `uncles` in one of the `forks`.
   * `block_number` - Denormalized `block` `number`. `nil` when transaction is pending or has only been collated into
     one of the `uncles` in one of the `forks`.
   * `block_consensus` - consensus of the block where transaction collated.
   * `block_timestamp` - timestamp of the block where transaction collated.
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
     Also, `error` is set if transaction is dropped/replaced
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
   * `has_error_in_internal_transactions` - shows if the internal transactions related to transaction have errors
   * `execution_node` - execution node address (used by Suave)
   * `execution_node_hash` - foreign key of `execution_node` (used by Suave)
   * `wrapped_type` - transaction type from the `wrapped` field (used by Suave)
   * `wrapped_nonce` - nonce from the `wrapped` field (used by Suave)
   * `wrapped_to_address` - target address from the `wrapped` field (used by Suave)
   * `wrapped_to_address_hash` - `wrapped_to_address` foreign key (used by Suave)
   * `wrapped_gas` - gas from the `wrapped` field (used by Suave)
   * `wrapped_gas_price` - gas_price from the `wrapped` field (used by Suave)
   * `wrapped_max_priority_fee_per_gas` - max_priority_fee_per_gas from the `wrapped` field (used by Suave)
   * `wrapped_max_fee_per_gas` - max_fee_per_gas from the `wrapped` field (used by Suave)
   * `wrapped_value` - value from the `wrapped` field (used by Suave)
   * `wrapped_input` - data from the `wrapped` field (used by Suave)
   * `wrapped_v` - V field of the signature from the `wrapped` field (used by Suave)
   * `wrapped_r` - R field of the signature from the `wrapped` field (used by Suave)
   * `wrapped_s` - S field of the signature from the `wrapped` field (used by Suave)
   * `wrapped_hash` - hash from the `wrapped` field (used by Suave)
  """
  Explorer.Chain.Transaction.Schema.generate()

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

  A pending transaction does not have a `gas_price` (Erigon)

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     gas: 4700000,
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

  A collated transaction MUST have an `index` so its position in the `block` is known and the `cumulative_gas_used` and
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
    attrs_to_cast =
      @required_attrs ++
        @optional_attrs ++
        @chain_type_optional_attrs

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

  @spec block_timestamp(t()) :: DateTime.t()
  def block_timestamp(%{block_number: nil, inserted_at: time}), do: time
  def block_timestamp(%{block_timestamp: time}) when not is_nil(time), do: time
  def block_timestamp(%{block: %{timestamp: time}}), do: time

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

  def decoded_revert_reason(transaction, revert_reason, options \\ []) do
    case revert_reason do
      nil ->
        nil

      "0x" <> hex_part ->
        process_hex_revert_reason(hex_part, transaction, options)

      hex ->
        process_hex_revert_reason(hex, transaction, options)
    end
  end

  @default_error_abi [
    %{
      "inputs" => [
        %{
          "name" => "reason",
          "type" => "string"
        }
      ],
      "name" => "Error",
      "type" => "error"
    },
    %{
      "inputs" => [
        %{
          "name" => "errorCode",
          "type" => "uint256"
        }
      ],
      "name" => "Panic",
      "type" => "error"
    }
  ]

  defp process_hex_revert_reason(hex_revert_reason, %__MODULE__{to_address: smart_contract, hash: hash}, options) do
    case Base.decode16(hex_revert_reason, case: :mixed) do
      {:ok, binary_revert_reason} ->
        case find_and_decode(@default_error_abi, binary_revert_reason, hash) do
          {:ok, {selector, values}} ->
            {:ok, mapping} = selector_mapping(selector, values, hash)
            identifier = Base.encode16(selector.method_id, case: :lower)
            text = function_call(selector.function, mapping)
            {:ok, identifier, text, mapping}

          _ ->
            decoded_input_data(
              %Transaction{
                to_address: smart_contract,
                hash: hash,
                input: %Data{bytes: binary_revert_reason}
              },
              options
            )
        end

      _ ->
        hex_revert_reason
    end
  end

  # Because there is no contract association, we know the contract was not verified
  @spec decoded_input_data(
          NotLoaded.t() | Transaction.t(),
          boolean(),
          [Chain.api?()],
          methods_map,
          smart_contract_full_abi_map
        ) :: error_type | success_type
        when methods_map: map(),
             smart_contract_full_abi_map: map(),
             error_type: {:error, any()} | {:error, :contract_not_verified | :contract_verified, list()},
             success_type: {:ok | binary(), any()} | {:ok, binary(), binary(), list()}
  def decoded_input_data(
        transaction,
        skip_sig_provider? \\ false,
        options,
        methods_map \\ %{},
        smart_contract_full_abi_map \\ %{}
      )

  # skip decoding if there is no to_address
  def decoded_input_data(
        %__MODULE__{to_address: nil},
        _,
        _,
        _,
        _
      ),
      do: {:error, :no_to_address}

  # skip decoding if transaction is not loaded
  def decoded_input_data(%NotLoaded{}, _, _, _, _),
    do: {:error, :not_loaded}

  # skip decoding if input is empty
  def decoded_input_data(
        %__MODULE__{input: %{bytes: bytes}},
        _,
        _,
        _,
        _
      )
      when bytes in [nil, <<>>] do
    {:error, :no_input_data}
  end

  # skip decoding if to_address is not a contract unless DECODE_NOT_A_CONTRACT_CALLS is set
  if not @decode_not_a_contract_calls do
    def decoded_input_data(
          %__MODULE__{to_address: %{contract_code: nil}},
          _,
          _,
          _,
          _
        ),
        do: {:error, :not_a_contract_call}
  end

  # if to_address's smart_contract is nil reduce to the case when to_address is not loaded
  def decoded_input_data(
        %__MODULE__{
          to_address: %{smart_contract: nil},
          input: input,
          hash: hash
        },
        skip_sig_provider?,
        options,
        methods_map,
        smart_contract_full_abi_map
      ) do
    decoded_input_data(
      %__MODULE__{
        to_address: %NotLoaded{},
        input: input,
        hash: hash
      },
      skip_sig_provider?,
      options,
      methods_map,
      smart_contract_full_abi_map
    )
  end

  # if to_address's smart_contract is not loaded reduce to the case when to_address is not loaded
  def decoded_input_data(
        %__MODULE__{
          to_address: %{smart_contract: %NotLoaded{}},
          input: input,
          hash: hash
        },
        skip_sig_provider?,
        options,
        methods_map,
        smart_contract_full_abi_map
      ) do
    decoded_input_data(
      %__MODULE__{
        to_address: %NotLoaded{},
        input: input,
        hash: hash
      },
      skip_sig_provider?,
      options,
      methods_map,
      smart_contract_full_abi_map
    )
  end

  # if to_address is not loaded try decoding by method candidates in the DB
  def decoded_input_data(
        %__MODULE__{
          to_address: %NotLoaded{},
          input: %{bytes: <<method_id::binary-size(4), _::binary>> = data} = input,
          hash: hash
        },
        skip_sig_provider?,
        options,
        methods_map,
        _smart_contract_full_abi_map
      ) do
    methods = check_methods_cache(method_id, methods_map, options)

    candidates =
      methods
      |> Enum.flat_map(fn candidate ->
        case do_decoded_input_data(
               data,
               [candidate.abi],
               hash
             ) do
          {:ok, _, _, _} = decoded -> [decoded]
          _ -> []
        end
      end)

    {:error, :contract_not_verified,
     if(candidates == [], do: decode_function_call_via_sig_provider(input, hash, skip_sig_provider?), else: candidates)}
  end

  # if to_address is not loaded and input is not a method call return error
  def decoded_input_data(
        %__MODULE__{to_address: %NotLoaded{}},
        _,
        _,
        _,
        _
      ) do
    {:error, :contract_not_verified, []}
  end

  def decoded_input_data(
        %__MODULE__{
          input: %{bytes: data} = input,
          to_address: %{smart_contract: smart_contract},
          hash: hash
        },
        skip_sig_provider?,
        options,
        methods_map,
        smart_contract_full_abi_map
      ) do
    full_abi = check_full_abi_cache(smart_contract, smart_contract_full_abi_map, options)

    case do_decoded_input_data(data, full_abi, hash) do
      # In some cases transactions use methods of some unpredictable contracts, so we can try to look up for method in a whole DB
      {:error, error} when error in [:could_not_decode, :no_matching_function] ->
        case decoded_input_data(
               %__MODULE__{
                 to_address: %NotLoaded{},
                 input: input,
                 hash: hash
               },
               skip_sig_provider?,
               options,
               methods_map,
               smart_contract_full_abi_map
             ) do
          {:error, :contract_not_verified, []} ->
            decode_function_call_via_sig_provider_wrapper(input, hash, skip_sig_provider?)

          {:error, :contract_not_verified, candidates} ->
            {:error, :contract_verified, candidates}

          _ ->
            {:error, :could_not_decode}
        end

      output ->
        output
    end
  end

  defp decode_function_call_via_sig_provider_wrapper(input, hash, skip_sig_provider?) do
    case decode_function_call_via_sig_provider(input, hash, skip_sig_provider?) do
      [] ->
        {:error, :could_not_decode}

      result ->
        {:error, :contract_verified, result}
    end
  end

  defp do_decoded_input_data(data, full_abi, hash) do
    with {:ok, {selector, values}} <- find_and_decode(full_abi, data, hash),
         {:ok, mapping} <- selector_mapping(selector, values, hash),
         identifier <- Base.encode16(selector.method_id, case: :lower),
         text <- function_call(selector.function, mapping) do
      {:ok, identifier, text, mapping}
    end
  end

  defp decode_function_call_via_sig_provider(%{bytes: data} = input, hash, skip_sig_provider?) do
    with true <- SigProviderInterface.enabled?(),
         false <- skip_sig_provider?,
         {:ok, result} <- SigProviderInterface.decode_function_call(input),
         true <- is_list(result),
         false <- Enum.empty?(result),
         abi <- [result |> List.first() |> Map.put("outputs", []) |> Map.put("type", "function")],
         {:ok, _, _, _} = candidate <- do_decoded_input_data(data, abi, hash) do
      [candidate]
    else
      _ ->
        []
    end
  end

  defp check_methods_cache(method_id, methods_map, options) do
    Map.get_lazy(methods_map, method_id, fn ->
      method_id
      |> ContractMethod.find_contract_method_query(1)
      |> Chain.select_repo(options).all()
    end)
  end

  defp check_full_abi_cache(
         smart_contract,
         smart_contract_full_abi_map,
         options
       ) do
    Map.get_lazy(smart_contract_full_abi_map, smart_contract.address_hash, fn ->
      Proxy.combine_proxy_implementation_abi(smart_contract, options)
    end)
  end

  def get_method_name(
        %__MODULE__{
          input: %{bytes: <<method_id::binary-size(4), _::binary>>}
        } = transaction
      ) do
    if transaction.created_contract_address_hash do
      nil
    else
      case decoded_input_data(
             %__MODULE__{
               to_address: %NotLoaded{},
               input: transaction.input,
               hash: transaction.hash
             },
             true,
             []
           ) do
        {:error, :contract_not_verified, [{:ok, _method_id, decoded_func, _}]} ->
          parse_method_name(decoded_func)

        {:error, :contract_not_verified, []} ->
          ExplorerHelper.add_0x_prefix(method_id)

        _ ->
          "Transfer"
      end
    end
  end

  def get_method_name(_), do: "Transfer"

  def parse_method_name(method_desc, need_upcase \\ true) do
    method_desc
    |> String.split("(")
    |> Enum.at(0)
    |> upcase_first(need_upcase)
  end

  defp upcase_first(string, false), do: string

  defp upcase_first(<<first::utf8, rest::binary>>, true), do: String.upcase(<<first::utf8>>) <> rest

  defp function_call(name, mapping) do
    text =
      mapping
      |> Stream.map(fn {name, type, _} -> [type, " ", name] end)
      |> Enum.intersperse(", ")

    IO.iodata_to_binary([name, "(", text, ")"])
  end

  defp find_and_decode(abi, data, hash) do
    with {%FunctionSelector{}, _mapping} = result <-
           abi
           |> ABI.parse_specification()
           |> ABI.find_and_decode(data) do
      {:ok, alter_inputs_names(result)}
    end
  rescue
    e ->
      Logger.warning(fn ->
        [
          "Could not decode input data for transaction: ",
          Hash.to_iodata(hash),
          Exception.format(:error, e, __STACKTRACE__)
        ]
      end)

      {:error, :could_not_decode}
  end

  defp alter_inputs_names({%FunctionSelector{input_names: names} = selector, mapping}) do
    names =
      names
      |> Enum.with_index()
      |> Enum.map(fn {name, index} ->
        if name == "", do: "arg#{index}", else: name
      end)

    {%FunctionSelector{selector | input_names: names}, mapping}
  end

  defp selector_mapping(selector, values, hash) do
    types = Enum.map(selector.types, &FunctionSelector.encode_type/1)

    mapping = Enum.zip([selector.input_names, types, values])

    {:ok, mapping}
  rescue
    e ->
      Logger.warning(fn ->
        [
          "Could not decode input data for transaction: ",
          Hash.to_iodata(hash),
          Exception.format(:error, e, __STACKTRACE__)
        ]
      end)

      {:error, :could_not_decode}
  end

  @doc """
  Produces a list of queries starting from the given one and adding filters for
  transactions that are linked to the given address_hash through a direction.
  """
  def matching_address_queries_list(query, :from, address_hashes) when is_list(address_hashes) do
    [
      from(
        a in fragment("SELECT unnest(?) as from_address_hash", type(^address_hashes, {:array, Hash.Address})),
        as: :address_hashes,
        cross_lateral_join:
          transaction in subquery(
            query
            |> where([transaction], transaction.from_address_hash == parent_as(:address_hashes).from_address_hash)
          ),
        as: :transaction,
        select: transaction
      )
    ]
  end

  def matching_address_queries_list(query, :to, address_hashes) when is_list(address_hashes) do
    [
      from(
        a in fragment("SELECT unnest(?) as to_address_hash", type(^address_hashes, {:array, Hash.Address})),
        as: :address_hashes,
        cross_lateral_join:
          transaction in subquery(
            query
            |> where([transaction], transaction.to_address_hash == parent_as(:address_hashes).to_address_hash)
          ),
        as: :transaction,
        select: transaction
      ),
      from(
        a in fragment(
          "SELECT unnest(?) as created_contract_address_hash",
          type(^address_hashes, {:array, Hash.Address})
        ),
        as: :address_hashes,
        cross_lateral_join:
          transaction in subquery(
            query
            |> where(
              [transaction],
              transaction.created_contract_address_hash == parent_as(:address_hashes).created_contract_address_hash
            )
          ),
        as: :transaction,
        select: transaction
      )
    ]
  end

  def matching_address_queries_list(query, _direction, address_hashes) when is_list(address_hashes) do
    matching_address_queries_list(query, :from, address_hashes) ++
      matching_address_queries_list(query, :to, address_hashes)
  end

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
    preloads = DenormalizationHelper.extend_block_preload([:from_address, :to_address, :created_contract_address])

    from(
      t in subquery(query),
      order_by: [desc: t.block_number, desc: t.index],
      preload: ^preloads
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
    preloads = DenormalizationHelper.extend_block_preload([:from_address, :to_address, :created_contract_address])

    from(
      t in subquery(query),
      order_by: [desc: t.block_number, desc: t.index],
      preload: ^preloads
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
  Builds an `Ecto.Query` to fetch transactions for the specified block_numbers
  """
  @spec transactions_for_block_numbers([non_neg_integer()]) :: Ecto.Query.t()
  def transactions_for_block_numbers(block_numbers) do
    from(
      t in Transaction,
      where: t.block_number in ^block_numbers
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions by hashes
  """
  @spec by_hashes_query([Hash.t()]) :: Ecto.Query.t()
  def by_hashes_query(hashes) do
    from(
      t in Transaction,
      where: t.hash in ^hashes
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

  @doc """
  Returns true if the transaction is a Rootstock REMASC transaction.
  """
  @spec rootstock_remasc_transaction?(Explorer.Chain.Transaction.t()) :: boolean
  def rootstock_remasc_transaction?(%__MODULE__{to_address_hash: to_address_hash}) do
    case Hash.Address.cast(Application.get_env(:explorer, __MODULE__)[:rootstock_remasc_address]) do
      {:ok, address} -> address == to_address_hash
      _ -> false
    end
  end

  @doc """
  Returns true if the transaction is a Rootstock bridge transaction.
  """
  @spec rootstock_bridge_transaction?(Explorer.Chain.Transaction.t()) :: boolean
  def rootstock_bridge_transaction?(%__MODULE__{to_address_hash: to_address_hash}) do
    case Hash.Address.cast(Application.get_env(:explorer, __MODULE__)[:rootstock_bridge_address]) do
      {:ok, address} -> address == to_address_hash
      _ -> false
    end
  end

  def bytes_to_address_hash(bytes), do: %Hash{byte_count: 20, bytes: bytes}

  @doc """
  Fetches the transactions related to the address with the given hash, including
  transactions that only have the address in the `token_transfers` related table
  and rewards for block validation.

  This query is divided into multiple subqueries intentionally in order to
  improve the listing performance.

  The `token_transfers` table tends to grow exponentially, and the query results
  with a `transactions` `join` statement takes too long.

  To solve this the `transaction_hashes` are fetched in a separate query, and
  paginated through the `block_number` already present in the `token_transfers`
  table.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec address_to_transactions_with_rewards(Hash.Address.t(), [
          Chain.paging_options() | Chain.necessity_by_association_option()
        ]) :: [__MODULE__.t()]
  def address_to_transactions_with_rewards(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:has_emission_funds] &&
           Keyword.get(options, :direction) != :from &&
           Reward.address_has_rewards?(address_hash) &&
           Reward.get_validator_payout_key_by_mining_from_db(address_hash, options) do
      %{payout_key: block_miner_payout_address}
      when not is_nil(block_miner_payout_address) and address_hash == block_miner_payout_address ->
        transactions_with_rewards_results(address_hash, options, paging_options)

      _ ->
        address_to_transactions_without_rewards(address_hash, options)
    end
  end

  defp transactions_with_rewards_results(address_hash, options, paging_options) do
    blocks_range = address_to_transactions_tasks_range_of_blocks(address_hash, options)

    rewards_task =
      Task.async(fn -> Reward.fetch_emission_rewards_tuples(address_hash, paging_options, blocks_range, options) end)

    [rewards_task | address_to_transactions_tasks(address_hash, options, true)]
    |> wait_for_address_transactions()
    |> Enum.sort_by(fn item ->
      case item do
        {%Reward{} = emission_reward, _} ->
          {-emission_reward.block.number, 1}

        item ->
          process_item(item)
      end
    end)
    |> Enum.dedup_by(fn item ->
      case item do
        {%Reward{} = emission_reward, _} ->
          {emission_reward.block_hash, emission_reward.address_hash, emission_reward.address_type}

        transaction ->
          transaction.hash
      end
    end)
    |> Enum.take(paging_options.page_size)
  end

  @doc false
  def address_to_transactions_tasks_range_of_blocks(address_hash, options) do
    extremums_list =
      address_hash
      |> transactions_block_numbers_at_address(options)
      |> Enum.map(fn query ->
        extremum_query =
          from(
            q in subquery(query),
            select: %{min_block_number: min(q.block_number), max_block_number: max(q.block_number)}
          )

        extremum_query
        |> Repo.one!()
      end)

    extremums_list
    |> Enum.reduce(%{min_block_number: nil, max_block_number: 0}, fn %{
                                                                       min_block_number: min_number,
                                                                       max_block_number: max_number
                                                                     },
                                                                     extremums_result ->
      current_min_number = Map.get(extremums_result, :min_block_number)
      current_max_number = Map.get(extremums_result, :max_block_number)

      extremums_result
      |> process_extremums_result_against_min_number(current_min_number, min_number)
      |> process_extremums_result_against_max_number(current_max_number, max_number)
    end)
  end

  defp transactions_block_numbers_at_address(address_hash, options) do
    direction = Keyword.get(options, :direction)

    options
    |> address_to_transactions_tasks_query(true)
    |> not_pending_transactions()
    |> select([t], t.block_number)
    |> matching_address_queries_list(direction, address_hash)
  end

  defp process_extremums_result_against_min_number(extremums_result, current_min_number, min_number)
       when is_number(current_min_number) and
              not (is_number(min_number) and min_number > 0 and min_number < current_min_number) do
    extremums_result
  end

  defp process_extremums_result_against_min_number(extremums_result, _current_min_number, min_number) do
    extremums_result
    |> Map.put(:min_block_number, min_number)
  end

  defp process_extremums_result_against_max_number(extremums_result, current_max_number, max_number)
       when is_number(max_number) and max_number > 0 and max_number > current_max_number do
    extremums_result
    |> Map.put(:max_block_number, max_number)
  end

  defp process_extremums_result_against_max_number(extremums_result, _current_max_number, _max_number) do
    extremums_result
  end

  defp process_item(item) do
    block_number = if item.block_number, do: -item.block_number, else: 0
    index = if item.index, do: -item.index, else: 0
    {block_number, index}
  end

  @spec address_to_transactions_without_rewards(
          Hash.Address.t(),
          [
            Chain.paging_options()
            | Chain.necessity_by_association_option()
            | {:sorting, SortingHelper.sorting_params()}
          ],
          boolean()
        ) :: [__MODULE__.t()]
  def address_to_transactions_without_rewards(address_hash, options, old_ui? \\ true) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    address_hash
    |> address_to_transactions_tasks(options, old_ui?)
    |> wait_for_address_transactions()
    |> Enum.sort(compare_custom_sorting(Keyword.get(options, :sorting, [])))
    |> Enum.dedup_by(& &1.hash)
    |> Enum.take(paging_options.page_size)
  end

  defp address_to_transactions_tasks(address_hash, options, old_ui?) do
    direction = Keyword.get(options, :direction)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    old_ui? = old_ui? || is_tuple(Keyword.get(options, :paging_options, Chain.default_paging_options()).key)

    options
    |> address_to_transactions_tasks_query(false, old_ui?)
    |> not_dropped_or_replaced_transactions()
    |> Chain.join_associations(necessity_by_association)
    |> put_has_token_transfers_to_transaction(old_ui?)
    |> matching_address_queries_list(direction, address_hash)
    |> Enum.map(fn query -> Task.async(fn -> Chain.select_repo(options).all(query) end) end)
  end

  @doc """
  Returns the address to transactions tasks query based on provided options.
  Boolean `only_mined?` argument specifies if only mined transactions should be returned,
  boolean `old_ui?` argument specifies if the query is for the old UI, i.e. is query dynamically sorted or no.
  """
  @spec address_to_transactions_tasks_query(keyword, boolean, boolean) :: Ecto.Query.t()
  def address_to_transactions_tasks_query(options, only_mined? \\ false, old_ui? \\ true)

  def address_to_transactions_tasks_query(options, only_mined?, true) do
    from_block = Chain.from_block(options)
    to_block = Chain.to_block(options)

    paging_options =
      options
      |> Keyword.get(:paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} -> []
      _ -> fetch_transactions(paging_options, from_block, to_block, !only_mined?)
    end
  end

  def address_to_transactions_tasks_query(options, _only_mined?, false) do
    from_block = Chain.from_block(options)
    to_block = Chain.to_block(options)
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    sorting_options = Keyword.get(options, :sorting, [])

    fetch_transactions_with_custom_sorting(paging_options, from_block, to_block, sorting_options)
  end

  @doc """
  Waits for the address transactions tasks to complete and returns the transactions flattened
  in case of success or raises an error otherwise.
  """
  @spec wait_for_address_transactions([Task.t()]) :: [__MODULE__.t()]
  def wait_for_address_transactions(tasks) do
    tasks
    |> Task.yield_many(:timer.seconds(20))
    |> Enum.flat_map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching address transactions terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching address transactions timed out."
      end
    end)
  end

  defp compare_custom_sorting([{order, :value}]) do
    fn a, b ->
      case Decimal.compare(Wei.to(a.value, :wei), Wei.to(b.value, :wei)) do
        :eq -> compare_default_sorting(a, b)
        :gt -> order == :desc
        :lt -> order == :asc
      end
    end
  end

  defp compare_custom_sorting([{block_order, :block_number}, {index_order, :index}]) do
    fn a, b ->
      case {Helper.compare(a.block_number, b.block_number), Helper.compare(a.index, b.index)} do
        {:eq, :eq} -> compare_default_sorting(a, b)
        {:eq, :gt} -> index_order == :desc
        {:eq, :lt} -> index_order == :asc
        {:gt, _} -> block_order == :desc
        {:lt, _} -> block_order == :asc
      end
    end
  end

  defp compare_custom_sorting([{:dynamic, :fee, order, _dynamic_fee}]) do
    fn a, b ->
      nil_case =
        case order do
          :desc_nulls_last -> Decimal.new("-inf")
          :asc_nulls_first -> Decimal.new("inf")
        end

      a_fee = a |> fee(:wei) |> elem(1) || nil_case
      b_fee = b |> fee(:wei) |> elem(1) || nil_case

      case Decimal.compare(a_fee, b_fee) do
        :eq -> compare_default_sorting(a, b)
        :gt -> order == :desc_nulls_last
        :lt -> order == :asc_nulls_first
      end
    end
  end

  defp compare_custom_sorting([]), do: &compare_default_sorting/2

  defp compare_default_sorting(a, b) do
    case {
      Helper.compare(a.block_number, b.block_number),
      Helper.compare(a.index, b.index),
      DateTime.compare(a.inserted_at, b.inserted_at),
      Helper.compare(Hash.to_integer(a.hash), Hash.to_integer(b.hash))
    } do
      {:lt, _, _, _} -> false
      {:eq, :lt, _, _} -> false
      {:eq, :eq, :lt, _} -> false
      {:eq, :eq, :eq, :gt} -> false
      _ -> true
    end
  end

  @doc """
  Creates a query to fetch transactions taking into account paging_options (possibly nil),
  from_block (may be nil), to_block (may be nil) and boolean `with_pending?` that indicates if pending transactions should be included
  into the query.
  """
  @spec fetch_transactions(PagingOptions.t() | nil, non_neg_integer | nil, non_neg_integer | nil, boolean()) ::
          Ecto.Query.t()
  def fetch_transactions(paging_options \\ nil, from_block \\ nil, to_block \\ nil, with_pending? \\ false) do
    __MODULE__
    |> order_for_transactions(with_pending?)
    |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
    |> handle_paging_options(paging_options)
  end

  @default_sorting [
    desc: :block_number,
    desc: :index,
    desc: :inserted_at,
    asc: :hash
  ]

  @doc """
  Creates a query to fetch transactions taking into account paging_options (possibly nil),
  from_block (may be nil), to_block (may be nil) and sorting_params.
  """
  @spec fetch_transactions_with_custom_sorting(
          PagingOptions.t() | nil,
          non_neg_integer | nil,
          non_neg_integer | nil,
          SortingHelper.sorting_params()
        ) :: Ecto.Query.t()
  def fetch_transactions_with_custom_sorting(paging_options, from_block, to_block, sorting) do
    query = from(transaction in __MODULE__)

    query
    |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
  end

  defp order_for_transactions(query, true) do
    query
    |> order_by([transaction],
      desc: transaction.block_number,
      desc: transaction.index,
      desc: transaction.inserted_at,
      asc: transaction.hash
    )
  end

  defp order_for_transactions(query, _) do
    query
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
  end

  @doc """
  Updates the provided query with necessary `where`s and `limit`s to take into account paging_options (may be nil).
  """
  @spec handle_paging_options(Ecto.Query.t() | atom, nil | Explorer.PagingOptions.t()) :: Ecto.Query.t()
  def handle_paging_options(query, nil), do: query

  def handle_paging_options(query, %PagingOptions{key: nil, page_size: nil}), do: query

  def handle_paging_options(query, paging_options) do
    query
    |> page_transaction(paging_options)
    |> limit(^paging_options.page_size)
  end

  @doc """
  Updates the provided query with necessary `where`s to take into account paging_options.
  """
  @spec page_transaction(Ecto.Query.t() | atom, Explorer.PagingOptions.t()) :: Ecto.Query.t()
  def page_transaction(query, %PagingOptions{key: nil}), do: query

  def page_transaction(query, %PagingOptions{is_pending_transaction: true} = options),
    do: page_pending_transaction(query, options)

  def page_transaction(query, %PagingOptions{key: {0, index}, is_index_in_asc_order: true}) do
    where(
      query,
      [transaction],
      transaction.block_number == 0 and transaction.index > ^index
    )
  end

  def page_transaction(query, %PagingOptions{key: {block_number, index}, is_index_in_asc_order: true}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index > ^index)
    )
  end

  def page_transaction(query, %PagingOptions{key: {0, 0}}) do
    query
  end

  def page_transaction(query, %PagingOptions{key: {block_number, 0}}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number
    )
  end

  def page_transaction(query, %PagingOptions{key: {block_number, index}}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index < ^index)
    )
  end

  def page_transaction(query, %PagingOptions{key: {0}}) do
    query
  end

  def page_transaction(query, %PagingOptions{key: {index}}) do
    where(query, [transaction], transaction.index < ^index)
  end

  @doc """
  Updates the provided query with necessary `where`s to take into account paging_options.
  """
  @spec page_pending_transaction(Ecto.Query.t() | atom, Explorer.PagingOptions.t()) :: Ecto.Query.t()
  def page_pending_transaction(query, %PagingOptions{key: nil}), do: query

  def page_pending_transaction(query, %PagingOptions{key: {inserted_at, hash}}) do
    where(
      query,
      [transaction],
      (is_nil(transaction.block_number) and
         (transaction.inserted_at < ^inserted_at or
            (transaction.inserted_at == ^inserted_at and transaction.hash > ^hash))) or
        not is_nil(transaction.block_number)
    )
  end

  @doc """
  Adds a `has_token_transfers` field to the query when second argument is `false`.

  When the second argument is `true`, returns the query untouched. When `false`,
  adds a field indicating whether the transaction has any token transfers by using
  a subquery to check if token_transfers table contains the transaction hash.

  ## Parameters
  - `query`: The Ecto query to be modified
  - `false_or_true`: Boolean indicating whether to add the field (when `false`) or
    leave the query untouched (when `true`)
  - `options`: Additional options for query construction
    - `:aliased?`: When `true`, uses the aliased transaction reference in the query

  ## Returns
  - The modified Ecto query with the `has_token_transfers` field added via
    `select_merge` (when second parameter is `false`)
  - The original query unchanged (when second parameter is `true`)
  """
  @spec put_has_token_transfers_to_transaction(Ecto.Query.t() | atom, boolean, keyword) :: Ecto.Query.t()
  def put_has_token_transfers_to_transaction(query, old_ui?, options \\ [])

  def put_has_token_transfers_to_transaction(query, true, _options), do: query

  def put_has_token_transfers_to_transaction(query, false, options) do
    aliased? = Keyword.get(options, :aliased?, false)

    if aliased? do
      from(transaction in query,
        select_merge: %{
          has_token_transfers:
            fragment(
              "(SELECT transaction_hash FROM token_transfers WHERE transaction_hash = ? LIMIT 1) IS NOT NULL",
              as(:transaction).hash
            )
        }
      )
    else
      from(transaction in query,
        select_merge: %{
          has_token_transfers:
            fragment(
              "(SELECT transaction_hash FROM token_transfers WHERE transaction_hash = ? LIMIT 1) IS NOT NULL",
              transaction.hash
            )
        }
      )
    end
  end

  @doc """
  Return the dynamic that calculates the fee for transactions.
  """
  @spec dynamic_fee :: Ecto.Query.dynamic_expr()
  def dynamic_fee do
    dynamic([transaction], transaction.gas_price * fragment("COALESCE(?, ?)", transaction.gas_used, transaction.gas))
  end

  @doc """
  Returns next page params based on the provided transaction.
  """
  @spec address_transactions_next_page_params(Explorer.Chain.Transaction.t()) :: %{
          required(String.t()) => Decimal.t() | Wei.t() | non_neg_integer | DateTime.t() | Hash.t()
        }
  def address_transactions_next_page_params(
        %__MODULE__{block_number: block_number, index: index, inserted_at: inserted_at, hash: hash, value: value} =
          transaction
      ) do
    %{
      "fee" => transaction |> fee(:wei) |> elem(1),
      "value" => value,
      "block_number" => block_number,
      "index" => index,
      "inserted_at" => inserted_at,
      "hash" => hash
    }
  end

  @doc """
  The fee a `transaction` paid for the `t:Explorer.Chain.Transaction.t/0` `gas`.

  If the transaction is pending, then the fee will be a range of `unit`

      iex> Explorer.Chain.Transaction.fee(
      ...>   %Explorer.Chain.Transaction{
      ...>     gas: Decimal.new(3),
      ...>     gas_price: %Explorer.Chain.Wei{value: Decimal.new(2)},
      ...>     gas_used: nil
      ...>   },
      ...>   :wei
      ...> )
      {:maximum, Decimal.new(6)}

  If the transaction has been confirmed in block, then the fee will be the actual fee paid in `unit` for the `gas_used`
  in the `transaction`.

      iex> Explorer.Chain.Transaction.fee(
      ...>   %Explorer.Chain.Transaction{
      ...>     gas: Decimal.new(3),
      ...>     gas_price: %Explorer.Chain.Wei{value: Decimal.new(2)},
      ...>     gas_used: Decimal.new(2)
      ...>   },
      ...>   :wei
      ...> )
      {:actual, Decimal.new(4)}

  """
  @spec fee(Transaction.t(), :ether | :gwei | :wei) :: {:maximum, Decimal.t()} | {:actual, Decimal.t() | nil}
  def fee(%Transaction{gas: _gas, gas_price: nil, gas_used: nil}, _unit), do: {:maximum, nil}

  def fee(%Transaction{gas: gas, gas_price: gas_price, gas_used: nil} = transaction, unit) do
    {:maximum, fee_calc(transaction, gas_price, gas, unit)}
  end

  if @chain_type == :optimism do
    def fee(%Transaction{gas_price: nil, gas_used: _gas_used}, _unit) do
      {:actual, nil}
    end
  else
    def fee(%Transaction{gas_price: nil, gas_used: gas_used} = transaction, unit) do
      gas_price = effective_gas_price(transaction)
      {:actual, gas_price && l2_fee_calc(gas_price, gas_used, unit)}
    end
  end

  def fee(%Transaction{gas_price: gas_price, gas_used: gas_used} = transaction, unit) do
    {:actual, fee_calc(transaction, gas_price, gas_used, unit)}
  end

  defp fee_calc(transaction, gas_price, gas_used, unit) do
    l1_fee =
      case Map.get(transaction, :l1_fee) do
        nil -> Wei.from(Decimal.new(0), :wei)
        value -> value
      end

    gas_price
    |> l2_fee_calc(gas_used, unit)
    |> Wei.from(unit)
    |> Wei.sum(l1_fee)
    |> Wei.to(unit)
  end

  @doc """
    The execution fee a `transaction` paid for the `t:Explorer.Chain.Transaction.t/0` `gas`.
    Doesn't include L1 fee. See the description for the `fee` function for parameters and return values.
  """
  @spec l2_fee(Transaction.t(), :ether | :gwei | :wei) :: {:maximum, Decimal.t() | nil} | {:actual, Decimal.t() | nil}
  def l2_fee(%Transaction{gas: _gas, gas_price: nil, gas_used: nil}, _unit), do: {:maximum, nil}

  def l2_fee(%Transaction{gas: gas, gas_price: gas_price, gas_used: nil}, unit) do
    {:maximum, l2_fee_calc(gas_price, gas, unit)}
  end

  def l2_fee(%Transaction{gas_price: nil, gas_used: gas_used} = transaction, unit) do
    gas_price = effective_gas_price(transaction)
    {:actual, gas_price && l2_fee_calc(gas_price, gas_used, unit)}
  end

  def l2_fee(%Transaction{gas_price: gas_price, gas_used: gas_used}, unit) do
    {:actual, l2_fee_calc(gas_price, gas_used, unit)}
  end

  defp l2_fee_calc(gas_price, gas_used, unit) do
    gas_price
    |> Wei.to(unit)
    |> Decimal.mult(gas_used)
  end

  @doc """
  Wrapper around `effective_gas_price/2`
  """
  @spec effective_gas_price(Transaction.t()) :: Wei.t() | nil
  def effective_gas_price(%Transaction{} = transaction), do: effective_gas_price(transaction, transaction.block)

  @doc """
  Calculates effective gas price for transaction with type 2 (EIP-1559)

  `effective_gas_price = priority_fee_per_gas + block.base_fee_per_gas`
  """
  @spec effective_gas_price(Transaction.t(), Block.t()) :: Wei.t() | nil

  def effective_gas_price(%Transaction{}, %NotLoaded{}), do: nil
  def effective_gas_price(%Transaction{}, nil), do: nil

  def effective_gas_price(%Transaction{} = transaction, block) do
    base_fee_per_gas = block.base_fee_per_gas
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas
    max_fee_per_gas = transaction.max_fee_per_gas

    priority_fee_per_gas = priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas)

    priority_fee_per_gas && Wei.sum(priority_fee_per_gas, base_fee_per_gas)
  end

  @doc """
    Calculates priority fee per gas for transaction with type 2 (EIP-1559)

    `priority_fee_per_gas = min(transaction.max_priority_fee_per_gas, transaction.max_fee_per_gas - block.base_fee_per_gas)`
  """
  @spec priority_fee_per_gas(Wei.t() | nil, Wei.t() | nil, Wei.t() | nil) :: Wei.t() | nil
  def priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas) do
    if is_nil(max_priority_fee_per_gas) or is_nil(base_fee_per_gas),
      do: nil,
      else:
        max_priority_fee_per_gas
        |> Wei.to(:wei)
        |> Decimal.min(max_fee_per_gas |> Wei.sub(base_fee_per_gas) |> Wei.to(:wei))
        |> Wei.from(:wei)
  end

  @doc """
  Dynamically adds to/from for `transactions` query based on whether the target address EOA or smart-contract
  EOAs with code (EIP-7702) are treated as regular EOAs.
  """
  @spec where_transactions_to_from(Hash.Address.t()) :: any()
  def where_transactions_to_from(address_hash) do
    with {:ok, address} <- Chain.hash_to_address(address_hash),
         true <- Address.smart_contract?(address),
         false <- Address.eoa_with_code?(address) do
      dynamic([transaction], transaction.to_address_hash == ^address_hash)
    else
      _ ->
        dynamic(
          [transaction],
          transaction.from_address_hash == ^address_hash or transaction.to_address_hash == ^address_hash
        )
    end
  end

  @doc """
    Returns the number of transactions included into the blocks of the specified block range.
    Only consensus blocks are taken into account.
  """
  @spec transaction_count_for_block_range(Range.t()) :: non_neg_integer()
  def transaction_count_for_block_range(from..to//_) do
    Repo.replica().aggregate(
      from(
        t in Transaction,
        where: t.block_number >= ^from and t.block_number <= ^to and t.block_consensus == true
      ),
      :count,
      timeout: :infinity
    )
  end

  @doc """
  Receives as input list of transactions and returns decoded_input_data
  Where
    - `decoded_input_data` is list of results: either `{:ok, _identifier, _text, _mapping}` or `nil`
  """
  @spec decode_transactions([Transaction.t()], boolean(), Keyword.t()) :: [nil | {:ok, String.t(), String.t(), map()}]
  def decode_transactions(transactions, skip_sig_provider?, opts) do
    smart_contract_full_abi_map = combine_smart_contract_full_abi_map(transactions)

    # first we assemble an empty methods map, so that decoded_input_data will skip ContractMethod.t() lookup and decoding
    empty_methods_map =
      transactions
      |> Enum.flat_map(fn
        %{input: %{bytes: <<method_id::binary-size(4), _::binary>>}} -> [method_id]
        _ -> []
      end)
      |> Enum.into(%{}, &{&1, []})

    # try to decode transaction using full abi data from smart_contract_full_abi_map
    decoded_transactions =
      transactions
      |> Enum.map(fn transaction ->
        transaction
        |> decoded_input_data(skip_sig_provider?, opts, empty_methods_map, smart_contract_full_abi_map)
        |> format_decoded_input()
      end)
      |> Enum.zip(transactions)

    # assemble a new methods map from methods in non-decoded transactions
    methods_map =
      decoded_transactions
      |> Enum.flat_map(fn
        {nil, %{input: %{bytes: <<method_id::binary-size(4), _::binary>>}}} -> [method_id]
        _ -> []
      end)
      |> Enum.uniq()
      |> ContractMethod.find_contract_methods(opts)
      |> Enum.into(empty_methods_map, &{&1.identifier, [&1]})

    # decode remaining transaction using methods map
    decoded_transactions
    |> Enum.map(fn
      {nil, transaction} ->
        transaction
        |> Map.put(:to_address, %NotLoaded{})
        |> decoded_input_data(skip_sig_provider?, opts, methods_map, smart_contract_full_abi_map)
        |> format_decoded_input()

      {decoded, _} ->
        decoded
    end)
  end

  defp combine_smart_contract_full_abi_map(transactions) do
    # parse unique address hashes of smart-contracts from to_address and created_contract_address properties of the transactions list
    unique_to_address_hashes =
      transactions
      |> Enum.flat_map(fn
        %Transaction{to_address: %Address{hash: hash}} -> [hash]
        %Transaction{created_contract_address: %Address{hash: hash}} -> [hash]
        _ -> []
      end)
      |> Enum.uniq()

    # query from the DB proxy implementation objects for those address hashes
    multiple_proxy_implementations =
      Implementation.get_proxy_implementations_for_multiple_proxies(unique_to_address_hashes)

    # query from the DB address objects with smart_contract preload for all found above proxy and implementation addresses
    addresses_with_smart_contracts =
      multiple_proxy_implementations
      |> Enum.flat_map(fn proxy_implementations -> proxy_implementations.address_hashes end)
      |> Enum.concat(unique_to_address_hashes)
      |> Chain.hashes_to_addresses(necessity_by_association: %{smart_contract: :optional})
      |> Enum.into(%{}, &{&1.hash, &1})

    # combine map %{proxy_address_hash => implementation address hashes}
    proxy_implementations_map =
      multiple_proxy_implementations
      |> Enum.into(%{}, &{&1.proxy_address_hash, &1.address_hashes})

    # combine map %{proxy_address_hash => combined proxy abi}
    unique_to_address_hashes
    |> Enum.into(%{}, fn to_address_hash ->
      full_abi =
        [to_address_hash | Map.get(proxy_implementations_map, to_address_hash, [])]
        |> Enum.map(&Map.get(addresses_with_smart_contracts, &1))
        |> Enum.flat_map(fn
          %{smart_contract: %{abi: abi}} when is_list(abi) -> abi
          _ -> []
        end)
        |> Enum.filter(&(!is_nil(&1)))

      {to_address_hash, full_abi}
    end)
  end

  @doc """
  Receives as input result of decoded_input_data/5, returns either nil or decoded input in format: {:ok, _identifier, _text, _mapping}
  """
  @spec format_decoded_input(any()) :: nil | {:ok, String.t(), String.t(), map()}
  def format_decoded_input({:error, _, []}), do: nil
  def format_decoded_input({:error, _, candidates}), do: Enum.at(candidates, 0)
  def format_decoded_input({:ok, _identifier, _text, _mapping} = decoded), do: decoded
  def format_decoded_input(_), do: nil

  @doc """
    Return method name used in tx
  """
  @spec method_name(t(), any(), boolean()) :: binary() | nil
  def method_name(_, _, skip_sc_check? \\ false)

  def method_name(_, {:ok, _method_id, text, _mapping}, _) do
    parse_method_name(text, false)
  end

  def method_name(
        %__MODULE__{to_address: to_address, input: %{bytes: <<method_id::binary-size(4), _::binary>>}},
        _,
        skip_sc_check?
      ) do
    if skip_sc_check? || Address.smart_contract?(to_address) do
      ExplorerHelper.add_0x_prefix(method_id)
    else
      nil
    end
  end

  def method_name(_, _, _) do
    nil
  end
end
