defmodule Explorer.Chain.Transaction.Schema do
  @moduledoc """
    Models transactions.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Transactions
  """
  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

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
                              field(:operator_fee_scalar, :decimal)
                              field(:operator_fee_constant, :decimal)
                              field(:da_footprint_gas_scalar, :decimal)
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

                        :zilliqa ->
                          alias Explorer.Chain.Zilliqa.Zrc2.TokenTransfer, as: Zrc2TokenTransfer

                          quote do
                            [
                              has_many(:zilliqa_zrc2_token_transfers, Zrc2TokenTransfer,
                                foreign_key: :transaction_hash,
                                references: :hash
                              )
                            ]
                          end

                        _ ->
                          []
                      end)

  @chain_identity_fields (case @chain_identity do
                            {:optimism, :celo} ->
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
        unquote_splicing(@chain_identity_fields)
      end
    end
  end
end

defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity],
    decode_not_a_contract_calls: [:explorer, :decode_not_a_contract_calls]

  use Utils.RuntimeEnvHelper,
    op_jovian_timestamp: [:indexer, [Indexer.Fetcher.Optimism.EIP1559ConfigUpdate, :jovian_timestamp_l2]]

  require Logger
  require Explorer.Chain.Transaction.Schema

  alias ABI.FunctionSelector
  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias EthereumJSONRPC
  alias EthereumJSONRPC.Transaction, as: EthereumJSONRPCTransaction
  alias Explorer.{Chain, Helper, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Address,
    Block,
    Block.Reward,
    ContractMethod,
    Data,
    DenormalizationHelper,
    Hash,
    InternalTransaction,
    MethodIdentifier,
    SmartContract.Proxy,
    TokenTransfer,
    Wei
  }

  alias Explorer.Chain.Block.Reader.General, as: BlockReaderGeneral

  alias Explorer.Chain.Cache.Transactions

  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  alias Explorer.SmartContract.SigProviderInterface

  @optional_attrs ~w(max_priority_fee_per_gas max_fee_per_gas block_hash block_number
                     block_consensus block_timestamp created_contract_address_hash
                     cumulative_gas_used earliest_processing_start error gas_price
                     gas_used index created_contract_code_indexed_at status
                     to_address_hash revert_reason type has_error_in_internal_transactions r s v)a

  @chain_type_optional_attrs (case @chain_type do
                                :optimism ->
                                  ~w(l1_fee l1_fee_scalar l1_gas_price l1_gas_used l1_transaction_origin l1_block_number operator_fee_scalar operator_fee_constant da_footprint_gas_scalar)a

                                :scroll ->
                                  ~w(l1_fee queue_index)a

                                :suave ->
                                  ~w(execution_node_hash wrapped_type wrapped_nonce wrapped_to_address_hash wrapped_gas wrapped_gas_price wrapped_max_priority_fee_per_gas wrapped_max_fee_per_gas wrapped_value wrapped_input wrapped_v wrapped_r wrapped_s wrapped_hash)a

                                :arbitrum ->
                                  ~w(gas_used_for_l1)a

                                _ ->
                                  ~w()a
                              end)

  @chain_identity_optional_attrs (case @chain_identity do
                                    {:optimism, :celo} ->
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
   * `operator_fee_scalar` - operatorFeeScalar is a uint32 scalar set by a chain operator (used by some OP chains)
   * `operator_fee_constant` - operatorFeeConstant is a uint64 constant set by a chain operator (used by some OP chains)
   * `da_footprint_gas_scalar` - daFootprintGasScalar is a uint16 scalar used to calculate daFootprint introduced in Jovian OP upgrade
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
        @chain_type_optional_attrs ++
        @chain_identity_optional_attrs

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
              %__MODULE__{
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
          NotLoaded.t() | __MODULE__.t(),
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

  if @chain_identity == {:optimism, :celo} do
    # Celo's Epoch logs does not have an associated transaction and linked to
    # the block instead, so we discard these token transfers for transaction
    # decoding
    def decoded_input_data(nil, _, _, _, _),
      do: {:error, :celo_epoch_log}
  end

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
    {:ok, method_id} = MethodIdentifier.cast(method_id)
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

  def decoded_input_data(
        %__MODULE__{to_address: %{metadata: _, ens_domain_name: _}},
        _,
        _,
        _,
        _
      ),
      do: {:error, :no_to_address}

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
          {:ok, method_id} = MethodIdentifier.cast(method_id)
          to_string(method_id)

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
  def matching_address_queries_list(query, direction, address_hashes, custom_sorting \\ [])

  def matching_address_queries_list(query, :from, address_hashes, _custom_sorting) when is_list(address_hashes) do
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

  def matching_address_queries_list(query, :to, address_hashes, _custom_sorting) when is_list(address_hashes) do
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

  def matching_address_queries_list(query, _direction, address_hashes, _custom_sorting) when is_list(address_hashes) do
    matching_address_queries_list(query, :from, address_hashes) ++
      matching_address_queries_list(query, :to, address_hashes)
  end

  # in ^[address_hash] addresses this issue: https://github.com/blockscout/blockscout/issues/12393
  def matching_address_queries_list(query, :from, address_hash, custom_sorting) do
    order =
      for {key, :block_number = value} <- custom_sorting do
        {value, key}
      end
      |> Keyword.get(:block_number, :desc)

    [
      query
      |> where([t], t.from_address_hash in ^[address_hash])
      |> prepend_order_by([t], [{^order, t.from_address_hash}])
    ]
  end

  def matching_address_queries_list(query, :to, address_hash, custom_sorting) do
    order =
      for {key, :block_number = value} <- custom_sorting do
        {value, key}
      end
      |> Keyword.get(:block_number, :desc)

    [
      query
      |> where([t], t.to_address_hash in ^[address_hash])
      |> prepend_order_by([t], [{^order, t.to_address_hash}]),
      query
      |> where(
        [t],
        t.created_contract_address_hash in ^[address_hash]
      )
      |> prepend_order_by([t], [{^order, t.created_contract_address_hash}])
    ]
  end

  def matching_address_queries_list(query, _direction, address_hash, custom_sorting) do
    matching_address_queries_list(query, :from, address_hash, custom_sorting) ++
      matching_address_queries_list(query, :to, address_hash, custom_sorting)
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
      t in __MODULE__,
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
      t in __MODULE__,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.from_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  defp transactions_with_token_transfers_query_direction(:to, address_hash) do
    from(
      t in __MODULE__,
      inner_join: tt in TokenTransfer,
      on: t.hash == tt.transaction_hash,
      where: tt.to_address_hash == ^address_hash,
      distinct: :hash
    )
  end

  defp transactions_with_token_transfers_query_direction(_, address_hash) do
    from(
      t in __MODULE__,
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
      t in __MODULE__,
      where: t.block_number == ^block_number
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions for the specified block_numbers
  """
  @spec transactions_for_block_numbers([non_neg_integer()]) :: Ecto.Query.t()
  def transactions_for_block_numbers(block_numbers) do
    from(
      t in __MODULE__,
      where: t.block_number in ^block_numbers
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions by hashes
  """
  @spec by_hashes_query([Hash.t()]) :: Ecto.Query.t()
  def by_hashes_query(hashes) do
    from(
      t in __MODULE__,
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
      t in __MODULE__,
      select: t.nonce,
      where: t.from_address_hash == ^address_hash,
      order_by: [desc: :block_number],
      limit: 1
    )
  end

  @doc """
  Streams a batch of transactions without OP operator fee for which the fee needs to be defined.

  This function selects specific fields from the transaction records and applies a reducer function to each entry in the stream, accumulating the result.

  ## Parameters
  - `initial`: The initial accumulator value.
  - `reducer`: A function that takes an entry and the current accumulator, returning the updated accumulator.
  - `start_timestamp`: A timestamp starting from which the transactions should be scanned.

  ## Returns
  - `{:ok, accumulator}`: A tuple containing `:ok` and the final accumulator after processing the stream.
  """
  @spec stream_transactions_without_operator_fee(
          initial :: accumulator,
          reducer :: (entry :: Hash.t(), accumulator -> accumulator),
          start_timestamp :: non_neg_integer()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_transactions_without_operator_fee(initial, reducer, start_timestamp) when is_function(reducer, 2) do
    limit = Application.get_env(:indexer, Indexer.Fetcher.Optimism.OperatorFee)[:init_limit]
    start_datetime = DateTime.from_unix!(start_timestamp)

    __MODULE__
    |> select([t], t.hash)
    |> where(
      [t],
      t.block_timestamp >= ^start_datetime and t.block_consensus == true and is_nil(t.operator_fee_constant)
    )
    |> limit(^limit)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns true if the transaction is a Rootstock REMASC transaction.
  """
  @spec rootstock_remasc_transaction?(__MODULE__.t()) :: boolean
  def rootstock_remasc_transaction?(%__MODULE__{to_address_hash: to_address_hash}) do
    case Hash.Address.cast(Application.get_env(:explorer, __MODULE__)[:rootstock_remasc_address]) do
      {:ok, address} -> address == to_address_hash
      _ -> false
    end
  end

  @doc """
  Returns true if the transaction is a Rootstock bridge transaction.
  """
  @spec rootstock_bridge_transaction?(__MODULE__.t()) :: boolean
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
    sorting_options = Keyword.get(options, :sorting, [])

    options
    |> address_to_transactions_tasks_query(false, old_ui?)
    |> not_dropped_or_replaced_transactions()
    |> Chain.join_associations(necessity_by_association)
    |> put_has_token_transfers_to_transaction(old_ui?)
    |> matching_address_queries_list(direction, address_hash, sorting_options)
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

  defp compare_custom_sorting([{:desc, :block_number}, {:desc, :index}, {:desc, :inserted_at}, {:asc, :hash}]),
    do: &compare_default_sorting/2

  defp compare_custom_sorting([{:asc, :block_number}, {:asc, :index}, {:asc, :inserted_at}, {:desc, :hash}]),
    do: &(!compare_default_sorting(&1, &2))

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
  @spec address_transactions_next_page_params(__MODULE__.t()) :: %{
          required(atom()) => Decimal.t() | Wei.t() | non_neg_integer | DateTime.t() | Hash.t()
        }
  def address_transactions_next_page_params(
        %__MODULE__{block_number: block_number, index: index, inserted_at: inserted_at, hash: hash, value: value} =
          transaction
      ) do
    %{
      fee: transaction |> fee(:wei) |> elem(1),
      value: value,
      block_number: block_number,
      index: index,
      inserted_at: inserted_at,
      hash: hash
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
  @spec fee(__MODULE__.t(), :ether | :gwei | :wei) :: {:maximum, Decimal.t() | nil} | {:actual, Decimal.t() | nil}
  def fee(%__MODULE__{gas: _gas, gas_price: nil, gas_used: nil}, _unit), do: {:maximum, nil}

  def fee(%__MODULE__{gas: gas, gas_price: _gas_price, gas_used: nil} = transaction, unit) do
    {:maximum, fee_calc(transaction, gas, unit)}
  end

  if @chain_type == :optimism do
    def fee(%__MODULE__{gas_price: nil, gas_used: _gas_used}, _unit) do
      {:actual, nil}
    end
  else
    def fee(%__MODULE__{gas_price: nil, gas_used: gas_used} = transaction, unit) do
      gas_price = effective_gas_price(transaction)
      {:actual, gas_price && l2_fee_calc(gas_price, gas_used, unit)}
    end
  end

  def fee(%__MODULE__{gas_price: _gas_price, gas_used: gas_used} = transaction, unit) do
    {:actual, fee_calc(transaction, gas_used, unit)}
  end

  # Internal function calculating a total fee of the transaction as follows:
  #   total_fee = l2_fee + l1_fee + operator_fee
  # The `operator_fee` is only calculated for OP chains (for others it's zero) starting from the Isthmus upgrade.
  #
  # ## Parameters
  # - `transaction`: The transaction entity.
  # - `gas_used`: The amount of gas used in the transaction. Equals to gas limit for pending transactions.
  # - `unit`: Which unit the result should be presented in. One of [:ether, :gwei, :wei].
  #
  # ## Returns
  # - The calculated total fee.
  @spec fee_calc(__MODULE__.t(), Decimal.t(), :ether | :gwei | :wei) :: Decimal.t()
  defp fee_calc(transaction, gas_used, unit) do
    l1_fee =
      case Map.get(transaction, :l1_fee) do
        nil -> Wei.from(Decimal.new(0), :wei)
        value -> value
      end

    {:ok, operator_fee} =
      transaction
      |> operator_fee()
      |> Wei.cast()

    transaction.gas_price
    |> l2_fee_calc(gas_used, unit)
    |> Wei.from(unit)
    |> Wei.sum(l1_fee)
    |> Wei.sum(operator_fee)
    |> Wei.to(unit)
  end

  @doc """
    The operator fee is calculated for OP chains starting from the Isthmus upgrade
    as described in https://specs.optimism.io/protocol/isthmus/exec-engine.html#operator-fee
    The formula changed in Jovian upgrade as follows:
    https://specs.optimism.io/protocol/jovian/exec-engine.html#fee-formula-update

    If the `operatorFeeScalar` or `operatorFeeConstant` is `nil`, it's treated as zero.

    ## Parameters
    - `transaction`: The transaction entity.

    ## Returns
    - The calculated operator fee for the given transaction.
  """
  @spec operator_fee(__MODULE__.t()) :: Decimal.t()
  def operator_fee(
        %__MODULE__{
          gas: gas,
          gas_used: gas_used
        } = transaction
      ) do
    gas_used = gas_used || gas
    operator_fee_scalar = Map.get(transaction, :operator_fee_scalar) || Decimal.new(0)
    operator_fee_constant = Map.get(transaction, :operator_fee_constant) || Decimal.new(0)

    jovian_timestamp = op_jovian_timestamp()

    block_timestamp =
      Map.get(transaction, :block_timestamp) || (jovian_timestamp && DateTime.from_unix!(jovian_timestamp)) ||
        DateTime.from_unix!(0)

    if DateTime.to_unix(block_timestamp) >= jovian_timestamp do
      # use the formula for Jovian
      gas_used
      |> Decimal.mult(operator_fee_scalar)
      |> Decimal.mult(100)
      |> Decimal.add(operator_fee_constant)
    else
      # use the formula for Isthmus
      gas_used
      |> Decimal.mult(operator_fee_scalar)
      |> Decimal.div_int(1_000_000)
      |> Decimal.add(operator_fee_constant)
    end
  end

  @doc """
    The execution fee a `transaction` paid for the `t:Explorer.Chain.Transaction.t/0` `gas`.
    Doesn't include L1 fee. See the description for the `fee` function for parameters and return values.
  """
  @spec l2_fee(__MODULE__.t(), :ether | :gwei | :wei) :: {:maximum, Decimal.t() | nil} | {:actual, Decimal.t() | nil}
  def l2_fee(%__MODULE__{gas: _gas, gas_price: nil, gas_used: nil}, _unit), do: {:maximum, nil}

  def l2_fee(%__MODULE__{gas: gas, gas_price: gas_price, gas_used: nil}, unit) do
    {:maximum, l2_fee_calc(gas_price, gas, unit)}
  end

  def l2_fee(%__MODULE__{gas_price: nil, gas_used: gas_used} = transaction, unit) do
    gas_price = effective_gas_price(transaction)
    {:actual, gas_price && l2_fee_calc(gas_price, gas_used, unit)}
  end

  def l2_fee(%__MODULE__{gas_price: gas_price, gas_used: gas_used}, unit) do
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
  @spec effective_gas_price(__MODULE__.t()) :: Wei.t() | nil
  def effective_gas_price(%__MODULE__{} = transaction), do: effective_gas_price(transaction, transaction.block)

  @doc """
  Calculates effective gas price for transaction with type 2 (EIP-1559)

  `effective_gas_price = priority_fee_per_gas + block.base_fee_per_gas`
  """
  @spec effective_gas_price(__MODULE__.t(), Block.t()) :: Wei.t() | nil

  def effective_gas_price(%__MODULE__{}, %NotLoaded{}), do: nil
  def effective_gas_price(%__MODULE__{}, nil), do: nil

  def effective_gas_price(%__MODULE__{} = transaction, block) do
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
        t in __MODULE__,
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
  @spec decode_transactions([__MODULE__.t()], boolean(), Keyword.t()) :: [nil | {:ok, String.t(), String.t(), map()}]
  def decode_transactions(transactions, skip_sig_provider?, opts) do
    smart_contract_full_abi_map = combine_smart_contract_full_abi_map(transactions)

    # first we assemble an empty methods map, so that decoded_input_data will skip ContractMethod.t() lookup and decoding
    empty_methods_map =
      transactions
      |> Enum.flat_map(fn
        %{input: %{bytes: <<method_id::binary-size(4), _::binary>>}} ->
          {:ok, method_id} = MethodIdentifier.cast(method_id)
          [method_id]

        _ ->
          []
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
    |> Enum.map(
      &decode_remaining_transaction(
        &1,
        skip_sig_provider?,
        opts,
        methods_map,
        smart_contract_full_abi_map
      )
    )
  end

  if @chain_identity == {:optimism, :celo} do
    defp decode_remaining_transaction({nil, nil}, _, _, _, _), do: nil
  end

  defp decode_remaining_transaction(
         {nil, transaction},
         skip_sig_provider?,
         opts,
         methods_map,
         smart_contract_full_abi_map
       ) do
    transaction
    |> Map.put(:to_address, %NotLoaded{})
    |> decoded_input_data(skip_sig_provider?, opts, methods_map, smart_contract_full_abi_map)
    |> format_decoded_input()
  end

  defp decode_remaining_transaction({decoded, _}, _, _, _, _), do: decoded

  defp combine_smart_contract_full_abi_map(transactions) do
    # parse unique address hashes of smart-contracts from to_address and created_contract_address properties of the transactions list
    unique_to_address_hashes =
      transactions
      |> Enum.flat_map(fn
        %__MODULE__{to_address: %Address{hash: hash}} -> [hash]
        %__MODULE__{created_contract_address: %Address{hash: hash}} -> [hash]
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
      {:ok, method_id} = MethodIdentifier.cast(method_id)
      method_id |> to_string()
    else
      nil
    end
  end

  def method_name(_, _, _) do
    nil
  end

  @doc """
    Return method id used in transaction
  """
  def method_id(%{
        created_contract_address_hash: nil,
        input: %{bytes: <<method_id::binary-size(4), _::binary>>}
      }),
      do: "0x" <> Base.encode16(method_id, case: :lower)

  def method_id(_transaction), do: "0x"

  @doc """
  Fetches the revert reason of a transaction.
  """
  @spec fetch_transaction_revert_reason(__MODULE__.t()) :: String.t()
  def fetch_transaction_revert_reason(transaction) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    hash_string = to_string(transaction.hash)

    response =
      InternalTransaction.fetch_first_trace(
        [
          %{
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            hash_data: hash_string,
            transaction_index: transaction.index
          }
        ],
        json_rpc_named_arguments
      )

    revert_reason =
      case response do
        {:ok, first_trace_params} ->
          first_trace_params |> Enum.at(0) |> Map.get(:output, %Data{bytes: <<>>}) |> to_string()

        {:error, reason} ->
          Logger.error(fn ->
            ["Error while fetching first trace for transaction: #{hash_string} error reason: ", inspect(reason)]
          end)

          fetch_transaction_revert_reason_using_call(transaction)

        :ignore ->
          fetch_transaction_revert_reason_using_call(transaction)
      end

    if !is_nil(revert_reason) do
      transaction
      |> Changeset.change(%{revert_reason: revert_reason})
      |> Repo.update()
    end

    revert_reason
  end

  defp fetch_transaction_revert_reason_using_call(%__MODULE__{
         block_number: block_number,
         to_address_hash: to_address_hash,
         from_address_hash: from_address_hash,
         input: data,
         gas: gas,
         gas_price: gas_price,
         value: value
       }) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    req =
      EthereumJSONRPCTransaction.eth_call_request(
        0,
        block_number,
        data,
        to_address_hash,
        from_address_hash,
        Wei.hex_format(gas),
        Wei.hex_format(gas_price),
        Wei.hex_format(value)
      )

    case EthereumJSONRPC.json_rpc(req, json_rpc_named_arguments) do
      {:error, error} ->
        Chain.parse_revert_reason_from_error(error)

      _ ->
        nil
    end
  end

  @default_page_size 50
  @default_paging_options %PagingOptions{page_size: @default_page_size}
  @limit_showing_transactions 10_000

  @doc """
  Returns the maximum number of transactions that can be shown in the UI.
  """
  @spec limit_showing_transactions :: non_neg_integer()
  def limit_showing_transactions, do: @limit_showing_transactions

  @doc """
  Returns the paged list of collated transactions that occurred recently from newest to oldest using `block_number`
  and `index`.

      iex> newest_first_transactions = 50 |> insert_list(:transaction) |> with_block() |> Enum.reverse()
      iex> oldest_seen = Enum.at(newest_first_transactions, 9)
      iex> paging_options = %Explorer.PagingOptions{page_size: 10, key: {oldest_seen.block_number, oldest_seen.index}}
      iex> recent_collated_transactions = Explorer.Chain.Transaction.recent_collated_transactions(true, paging_options: paging_options)
      iex> length(recent_collated_transactions)
      10
      iex> hd(recent_collated_transactions).hash == Enum.at(newest_first_transactions, 10).hash
      true

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Transaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec recent_collated_transactions(true | false, [Chain.paging_options() | Chain.necessity_by_association_option() | Chain.api?()]) :: [t()]
  def recent_collated_transactions(old_ui?, options \\ [])
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    method_id_filter = Keyword.get(options, :method)
    type_filter = Keyword.get(options, :type)

    case !paging_options.key && Transactions.atomic_take_enough(paging_options.page_size) do
      transactions when is_list(transactions) ->
        transactions |> select_repo(options).preload(Map.keys(necessity_by_association))

      _ ->
        fetch_recent_collated_transactions(
          old_ui?,
          paging_options,
          necessity_by_association,
          method_id_filter,
          type_filter,
          options
        )
    end
  end

  defp fetch_recent_collated_transactions(
         old_ui?,
         paging_options,
         necessity_by_association,
         method_id_filter,
         type_filter,
         options
       ) do
    case paging_options do
      %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} ->
        []

      _ ->
        paging_options
        |> fetch_transactions()
        |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
        |> apply_filter_by_method_id_to_transactions(method_id_filter)
        |> apply_filter_by_type_to_transactions(type_filter)
        |> Chain.join_associations(necessity_by_association)
        |> put_has_token_transfers_to_transaction(old_ui?)
        |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
        |> Chain.select_repo(options).all()
    end
  end

  @doc """
  Applies a filter to the query based on the method ID of the transaction.
  """
  @spec apply_filter_by_method_id_to_transactions(query :: Ecto.Query.t(), filter :: list() | nil) :: Ecto.Query.t()
  def apply_filter_by_method_id_to_transactions(query, nil), do: query

  def apply_filter_by_method_id_to_transactions(query, filter) when is_list(filter) do
    method_ids = Enum.flat_map(filter, &map_name_or_method_id_to_method_id/1)

    if method_ids != [] do
      query
      |> where([transaction], fragment("SUBSTRING(? FOR 4)", transaction.input) in ^method_ids)
    else
      query
    end
  end

  def apply_filter_by_method_id_to_transactions(query, filter),
    do: apply_filter_by_method_id_to_transactions(query, [filter])

  @method_name_to_id_map %{
    "approve" => "095ea7b3",
    "transfer" => "a9059cbb",
    "multicall" => "5ae401dc",
    "mint" => "40c10f19",
    "commit" => "f14fcbc8"
  }

  defp map_name_or_method_id_to_method_id(string) when is_binary(string) do
    if id = @method_name_to_id_map[string] do
      decode_method_id(id)
    else
      trimmed =
        string
        |> String.replace("0x", "", global: false)

      decode_method_id(trimmed)
    end
  end

  defp decode_method_id(method_id) when is_binary(method_id) do
    case String.length(method_id) == 8 && Base.decode16(method_id, case: :mixed) do
      {:ok, bytes} ->
        [bytes]

      _ ->
        []
    end
  end

  @doc """
  Applies a filter to the query based on the type of transaction.
  """
  @spec apply_filter_by_type_to_transactions(query :: Ecto.Query.t(), filter :: list()) :: Ecto.Query.t()
  def apply_filter_by_type_to_transactions(query, [_ | _] = filter) do
    {dynamic, modified_query} = apply_filter_by_type_to_transactions_inner(filter, query)

    modified_query
    |> where(^dynamic)
  end

  def apply_filter_by_type_to_transactions(query, _filter), do: query

  defp apply_filter_by_type_to_transactions_inner(dynamic \\ dynamic(false), filter, query)

  defp apply_filter_by_type_to_transactions_inner(dynamic, [type | remain], query) do
    case type do
      :contract_call ->
        dynamic
        |> filter_contract_call_dynamic()
        |> apply_filter_by_type_to_transactions_inner(
          remain,
          join(query, :inner, [transaction], address in assoc(transaction, :to_address), as: :to_address)
        )

      :contract_creation ->
        dynamic
        |> filter_contract_creation_dynamic()
        |> apply_filter_by_type_to_transactions_inner(remain, query)

      :coin_transfer ->
        dynamic
        |> filter_transaction_dynamic()
        |> apply_filter_by_type_to_transactions_inner(remain, query)

      :token_transfer ->
        dynamic
        |> filter_token_transfer_dynamic()
        |> apply_filter_by_type_to_transactions_inner(remain, query)

      :token_creation ->
        dynamic
        |> filter_token_creation_dynamic()
        |> apply_filter_by_type_to_transactions_inner(
          remain,
          join(query, :inner, [transaction], token in Token,
            on: token.contract_address_hash == transaction.created_contract_address_hash,
            as: :created_token
          )
        )

      :blob_transaction ->
        dynamic
        |> filter_blob_transaction_dynamic()
        |> apply_filter_by_type_to_transactions_inner(remain, query)
    end
  end

  defp apply_filter_by_type_to_transactions_inner(dynamic_query, _, query), do: {dynamic_query, query}

  defp filter_contract_creation_dynamic(dynamic) do
    dynamic([transaction], ^dynamic or is_nil(transaction.to_address_hash))
  end

  defp filter_transaction_dynamic(dynamic) do
    dynamic([transaction], ^dynamic or transaction.value > ^0)
  end

  defp filter_contract_call_dynamic(dynamic) do
    dynamic([transaction, to_address: to_address], ^dynamic or not is_nil(to_address.contract_code))
  end

  defp filter_token_transfer_dynamic(dynamic) do
    # TokenTransfer.__struct__.__meta__.source
    dynamic(
      [transaction],
      ^dynamic or
        fragment(
          "NOT (SELECT transaction_hash FROM token_transfers WHERE transaction_hash = ? LIMIT 1) IS NULL",
          transaction.hash
        )
    )
  end

  defp filter_token_creation_dynamic(dynamic) do
    dynamic([transaction, created_token: created_token], ^dynamic or not is_nil(created_token))
  end

  defp filter_blob_transaction_dynamic(dynamic) do
    # EIP-2718 blob transaction type
    dynamic([transaction], ^dynamic or transaction.type == 3)
  end




  @doc """
  Returns the count of available transactions shown in the UI.

  This function returns the number of transactions that have been mined and are
  available for display, up to a maximum of #{@limit_showing_transactions} transactions.

  ## Returns
  - The count of available transactions (non-negative integer)
  """
  @spec transactions_available_count() :: non_neg_integer()
  def transactions_available_count do
    __MODULE__
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> limit(^@limit_showing_transactions)
    |> Repo.aggregate(:count, :hash)
  end

  defp handle_random_access_paging_options(query, empty_options) when empty_options in [nil, [], %{}],
    do: limit(query, ^(@default_page_size + 1))

  defp handle_random_access_paging_options(query, paging_options) do
    query
    |> (&if(paging_options |> Map.get(:page_number, 1) |> process_page_number() == 1,
          do: &1,
          else: __MODULE__.page_transaction(&1, paging_options)
        )).()
    |> handle_page(paging_options)
  end

  defp handle_page(query, paging_options) do
    page_number = paging_options |> Map.get(:page_number, 1) |> process_page_number()
    page_size = Map.get(paging_options, :page_size, @default_page_size)

    cond do
      page_in_bounds?(page_number, page_size) && page_number == 1 ->
        query
        |> limit(^(page_size + 1))

      page_in_bounds?(page_number, page_size) ->
        query
        |> limit(^page_size)
        |> offset(^((page_number - 2) * page_size))

      true ->
        query
        |> limit(^(@default_page_size + 1))
    end
  end

  defp process_page_number(number) when number < 1, do: 1

  defp process_page_number(number), do: number

  defp page_in_bounds?(page_number, page_size),
    do: page_size <= @limit_showing_transactions && @limit_showing_transactions - page_number * page_size >= 0

  @doc """
  Finds and updates replaced transactions in the database.
  """
  @spec find_and_update_replaced_transactions([
          %{
            required(:nonce) => non_neg_integer,
            required(:from_address_hash) => Hash.Address.t(),
            required(:hash) => Hash.t()
          }
        ]) :: {integer(), nil | [term()]}
  def find_and_update_replaced_transactions(transactions, timeout \\ :infinity) do
    query =
      transactions
      |> Enum.reduce(
        __MODULE__,
        fn %{hash: hash, nonce: nonce, from_address_hash: from_address_hash}, query ->
          from(t in query,
            or_where:
              t.nonce == ^nonce and t.from_address_hash == ^from_address_hash and t.hash != ^hash and
                not is_nil(t.block_number)
          )
        end
      )
      # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
      |> order_by(asc: :hash)
      |> lock("FOR NO KEY UPDATE")

    hashes = Enum.map(transactions, & &1.hash)

    transactions_to_update =
      from(pending in __MODULE__,
        join: duplicate in subquery(query),
        on: duplicate.nonce == pending.nonce and duplicate.from_address_hash == pending.from_address_hash,
        where: pending.hash in ^hashes and is_nil(pending.block_hash)
      )

    Repo.update_all(transactions_to_update, [set: [error: "dropped/replaced", status: :error]], timeout: timeout)
  end

  @doc """
  Updates the replaced transactions in the database.
  """
  @spec update_replaced_transactions([
          %{
            required(:nonce) => non_neg_integer,
            required(:from_address_hash) => Hash.Address.t(),
            required(:block_hash) => Hash.Full.t()
          }
        ]) :: {integer(), nil | [term()]}
  def update_replaced_transactions(transactions, timeout \\ :infinity) do
    filters =
      transactions
      |> Enum.filter(fn transaction ->
        transaction.block_hash && transaction.nonce && transaction.from_address_hash
      end)
      |> Enum.map(fn transaction ->
        {transaction.nonce, transaction.from_address_hash}
      end)
      |> Enum.uniq()

    if Enum.empty?(filters) do
      {0, []}
    else
      query =
        filters
        |> Enum.reduce(__MODULE__, fn {nonce, from_address}, query ->
          from(t in query,
            or_where:
              t.nonce == ^nonce and
                t.from_address_hash == ^from_address and
                is_nil(t.block_hash) and
                (is_nil(t.error) or t.error != "dropped/replaced")
          )
        end)
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        |> order_by(asc: :hash)
        |> lock("FOR NO KEY UPDATE")

      Repo.update_all(
        from(t in __MODULE__, join: s in subquery(query), on: t.hash == s.hash),
        [set: [error: "dropped/replaced", status: :error]],
        timeout: timeout
      )
    end
  end

  @doc """
  Streams pending transactions with the given fields.
  """
  @spec stream_pending_transactions(
          fields :: [
            :block_hash
            | :created_contract_code_indexed_at
            | :from_address_hash
            | :gas
            | :gas_price
            | :hash
            | :index
            | :input
            | :nonce
            | :r
            | :s
            | :to_address_hash
            | :v
            | :value
          ],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_pending_transactions(fields, initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    query =
      __MODULE__
      |> pending_transactions_query()
      |> select(^fields)
      |> Chain.add_fetcher_limit(limited?)

    Repo.stream_reduce(query, initial, reducer)
  end

  @doc """
  Query to return all pending transactions
  """
  @spec pending_transactions_query(Ecto.Queryable.t()) :: Ecto.Queryable.t()
  def pending_transactions_query(query) do
    from(transaction in query,
      where: is_nil(transaction.block_hash) and (is_nil(transaction.error) or transaction.error != "dropped/replaced")
    )
  end

  @doc """
  Returns pending transactions list from the DB
  """
  @spec pending_transactions_list() :: Ecto.Schema.t() | term()
  def pending_transactions_list do
    __MODULE__
    |> pending_transactions_query()
    |> where([t], t.inserted_at < ago(1, "day"))
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  Return the list of pending transactions that occurred recently.

      iex> 2 |> insert_list(:transaction)
      iex> :transaction |> insert() |> with_block()
      iex> 8 |> insert_list(:transaction)
      iex> recent_pending_transactions = Explorer.Chain.Transaction.recent_pending_transactions()
      iex> length(recent_pending_transactions)
      10
      iex> Enum.all?(recent_pending_transactions, fn %Explorer.Chain.Transaction{block_hash: block_hash} ->
      ...>   is_nil(block_hash)
      ...> end)
      true

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Transaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` (defaults to
      `#{@default_paging_options.page_size}`) and `:key` (a tuple of the lowest/oldest `{inserted_at, hash}`) and.
      Results will be the transactions older than the `inserted_at` and `hash` that are passed.

  """
  @spec recent_pending_transactions([Chain.paging_options() | Chain.necessity_by_association_option()], true | false) ::
          [
            __MODULE__.t()
          ]
  def recent_pending_transactions(options \\ [], old_ui? \\ true)
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    method_id_filter = Keyword.get(options, :method)
    type_filter = Keyword.get(options, :type)

    __MODULE__
    |> page_pending_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> pending_transactions_query()
    |> apply_filter_by_method_id_to_transactions(method_id_filter)
    |> apply_filter_by_type_to_transactions(type_filter)
    |> order_by([transaction], desc: transaction.inserted_at, asc: transaction.hash)
    |> Chain.join_associations(necessity_by_association)
    |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
    |> Chain.select_repo(options).all()
  end

  @doc """
  Finds all transactions of a certain block number
  """
  def get_transactions_of_block_number(block_number) do
    block_number
    |> transactions_with_block_number()
    |> Repo.all()
  end

  @doc """
  Finds all transactions of a certain block numbers
  """
  def get_transactions_of_block_numbers(block_numbers) do
    block_numbers
    |> transactions_for_block_numbers()
    |> Repo.all()
  end

  @doc """
  Finds transactions by hashes
  """
  @spec get_transactions_by_hashes([Hash.t()]) :: [__MODULE__.t()]
  def get_transactions_by_hashes(transaction_hashes) do
    transaction_hashes
    |> by_hashes_query()
    |> Repo.all()
  end

  @doc """
  Checks if a `t:Explorer.Chain.Transaction.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> %Transaction{hash: hash} = insert(:transaction)
      iex> Explorer.Chain.Transaction.check_transaction_exists(hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.Transaction.check_transaction_exists(hash)
      :not_found
  """
  @spec check_transaction_exists(Hash.Full.t()) :: :ok | :not_found
  def check_transaction_exists(hash) do
    hash
    |> transaction_exists?()
    |> Chain.boolean_to_check_result()
  end

  # Checks if a `t:Explorer.Chain.Transaction.t/0` with the given `hash` exists.

  # Returns `true` if found

  #     iex> %Transaction{hash: hash} = insert(:transaction)
  #     iex> Explorer.Chain.transaction_exists?(hash)
  #     true

  # Returns `false` if not found

  #     iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
  #     ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
  #     ...> )
  #     iex> Explorer.Chain.transaction_exists?(hash)
  #     false
  @spec transaction_exists?(Hash.Full.t()) :: boolean()
  defp transaction_exists?(hash) do
    query =
      from(
        transaction in __MODULE__,
        where: transaction.hash == ^hash
      )

    Repo.exists?(query)
  end
end
