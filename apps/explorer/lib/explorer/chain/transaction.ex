defmodule Explorer.Chain.Transaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  import Ecto.Query, only: [from: 2, join: 5, preload: 3]

  alias Ecto.Changeset

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Gas,
    Hash,
    InternalTransaction,
    Log,
    TokenTransfer,
    Wei
  }

  alias Explorer.Chain.Transaction.Status

  @optional_attrs ~w(block_hash block_number created_contract_address_hash cumulative_gas_used gas_used index internal_transactions_indexed_at status
                     to_address_hash)a
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
   * `block` - the block in which this transaction was mined/validated.  `nil` when transaction is pending.
   * `block_hash` - `block` foreign key. `nil` when transaction is pending.
   * `block_number` - Denormalized `block` `number`. `nil` when transaction is pending.
   * `created_contract_address` - belongs_to association to `address` corresponding to `created_contract_address_hash`.
   * `created_contract_address_hash` - Denormalized `internal_transaction` `created_contract_address_hash`
     populated only when `to_address_hash` is nil.
   * `cumulative_gas_used` - the cumulative gas used in `transaction`'s `t:Explorer.Chain.Block.t/0` before
     `transaction`'s `index`.  `nil` when transaction is pending.
   * `from_address` - the source of `value`
   * `from_address_hash` - foreign key of `from_address`
   * `gas` - Gas provided by the sender
   * `gas_price` - How much the sender is willing to pay for `gas`
   * `gas_used` - the gas used for just `transaction`.  `nil` when transaction is pending.
   * `hash` - hash of contents of this transaction
   * `index` - index of this transaction in `block`.  `nil` when transaction is pending.
   * `input`- data sent along with the transaction
   * `internal_transactions` - transactions (value transfers) created while executing contract used for this
     transaction
   * `internal_transactions_indexed_at` - when `internal_transactions` were fetched by `Indexer`.
   * `logs` - events that occurred while mining the `transaction`.
   * `nonce` - the number of transaction made by the sender prior to this one
   * `r` - the R field of the signature. The (r, s) is the normal output of an ECDSA signature, where r is computed as
       the X coordinate of a point R, modulo the curve order n.
   * `s` - The S field of the signature.  The (r, s) is the normal output of an ECDSA signature, where r is computed as
       the X coordinate of a point R, modulo the curve order n.
   * `status` - whether the transaction was successfully mined or failed.  `nil` when transaction is pending.
   * `to_address` - sink of `value`
   * `to_address_hash` - `to_address` foreign key
   * `v` - The V field of the signature.
   * `value` - wei transferred from `from_address` to `to_address`
  """
  @type t :: %__MODULE__{
          block: %Ecto.Association.NotLoaded{} | Block.t() | nil,
          block_hash: Hash.t() | nil,
          block_number: Block.block_number() | nil,
          created_contract_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          created_contract_address_hash: Hash.Address.t() | nil,
          cumulative_gas_used: Gas.t() | nil,
          from_address: %Ecto.Association.NotLoaded{} | Address.t(),
          from_address_hash: Hash.Address.t(),
          gas: Gas.t(),
          gas_price: wei_per_gas,
          gas_used: Gas.t() | nil,
          hash: Hash.t(),
          index: transaction_index | nil,
          input: Data.t(),
          internal_transactions: %Ecto.Association.NotLoaded{} | [InternalTransaction.t()],
          internal_transactions_indexed_at: DateTime.t(),
          logs: %Ecto.Association.NotLoaded{} | [Log.t()],
          nonce: non_neg_integer(),
          r: r(),
          s: s(),
          status: Status.t() | nil,
          to_address: %Ecto.Association.NotLoaded{} | Address.t() | nil,
          to_address_hash: Hash.Address.t() | nil,
          v: v(),
          value: Wei.t()
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "transactions" do
    field(:block_number, :integer)
    field(:cumulative_gas_used, :decimal)
    field(:gas, :decimal)
    field(:gas_price, Wei)
    field(:gas_used, :decimal)
    field(:index, :integer)
    field(:internal_transactions_indexed_at, :utc_datetime)
    field(:input, Data)
    field(:nonce, :integer)
    field(:r, :decimal)
    field(:s, :decimal)
    field(:status, Status)
    field(:v, :integer)
    field(:value, Wei)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full)

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

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  @doc """
  A pending transaction has neither `block_hash` nor an `index`

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

  A pending transaction (which is indicated by not having a `block_hash`) can't have `block_number`,
  `cumulative_gas_used`, `gas_used`, or `index`.

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
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
      false
      iex> Keyword.get_values(changeset.errors, :block_number)
      [{"can't be set when the transaction is pending", []}]
      iex> Keyword.get_values(changeset.errors, :cumulative_gas_used)
      [{"can't be set when the transaction is pending", []}]
      iex> Keyword.get_values(changeset.errors, :gas_used)
      [{"can't be set when the transaction is pending", []}]
      iex> Keyword.get_values(changeset.errors, :index)
      [{"can't be set when the transaction is pending", []}]
      iex> Keyword.get_values(changeset.errors, :status)
      [{"can't be set when the transaction is pending", []}]

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

  Once the `internal_transactions_indexed_at` is set, both pre- and post-Byzantium transactions will be able to know
  their status, so if `internal_transaction_indexed_at` is set, `status` is required.

      iex> changeset = Explorer.Chain.Transaction.changeset(
      ...>   %Transaction{},
      ...>   %{
      ...>     block_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     block_number: 34,
      ...>     cumulative_gas_used: 0,
      ...>     gas: 4700000,
      ...>     gas_price: 100000000000,
      ...>     gas_used: 4600000,
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     index: 0,
      ...>     input: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     internal_transactions_indexed_at: DateTime.utc_now(),
      ...>     nonce: 0,
      ...>     r: 0xAD3733DF250C87556335FFE46C23E34DBAFFDE93097EF92F52C88632A40F0C75,
      ...>     s: 0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3,
      ...>     v: 0x8d,
      ...>     value: 0
      ...>   }
      ...> )
      iex> changeset.valid?
      false
      iex> Keyword.get_values(changeset.errors, :status)
      [{"can't be blank when the internal transactions have been fetched", [validation: :required]}]

  """
  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> validate_collated_or_pending()
    |> validate_status()
    |> check_pending()
    |> check_collated()
    |> check_status()
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:hash)
  end

  def preload_token_transfers(query, address_hash) do
    token_transfers_query =
      from(
        tt in TokenTransfer,
        where:
          tt.token_contract_address_hash == ^address_hash or tt.to_address_hash == ^address_hash or
            tt.from_address_hash == ^address_hash,
        preload: [:token, [from_address: :names], [to_address: :names]]
      )

    preload(query, [tt], token_transfers: ^token_transfers_query)
  end

  @doc """
  Adds to the given transaction's query a `where` with one of the conditions that the matched
  function returns.

  `where_address_fields_match(query, address, :to)`
  - returns a query considering that the given address_hash is equal to to_address_hash from
    transactions' table or is equal to to_address_hash from token transfers' table.

  `where_address_fields_match(query, address, :from)`
  - returns a query considering that the given address_hash is equal to from_address_hash from
    transactions' table or is equal to from_address_hash from token transfers' table.

  `where_address_fields_match(query, address, nil)`
  - returns a query considering that the given address_hash can be: to_address_hash,
    from_address_hash, created_contract_address_hash,
    to_address_hash or from_address_hash from token_transfers' table.

  ### Token transfers' preload

  Token transfers will be preloaded according to the given address_hash considering if it's equal
  to token_contract_address_hash, to_address_hash or from_address_hash from Token Transfers's table.
  """
  def where_address_fields_match(query, address_hash, :to) do
    join(
      query,
      :inner,
      [transaction],
      matches in fragment(
        """
        WITH hashes AS (
          (
            SELECT t0.hash AS hash
            FROM transactions AS t0
            WHERE t0.to_address_hash = ? OR t0.created_contract_address_hash = ?
          )
          UNION ALL
          (
            SELECT tt.transaction_hash AS hash
            FROM token_transfers AS tt
            WHERE tt.to_address_hash = ?
          )
        ) SELECT * from hashes
        """,
        ^address_hash.bytes,
        ^address_hash.bytes,
        ^address_hash.bytes
      ),
      transaction.hash == matches.hash
    )
  end

  def where_address_fields_match(query, address_hash, :from) do
    join(
      query,
      :inner,
      [transaction],
      matches in fragment(
        """
        WITH hashes AS (
          (
            SELECT t0.hash AS hash
            FROM transactions AS t0
            WHERE t0.from_address_hash = ?
          )
          UNION ALL
          (
            SELECT tt.transaction_hash AS hash
            FROM token_transfers AS tt
            WHERE tt.from_address_hash = ?
          )
        ) SELECT * from hashes
        """,
        ^address_hash.bytes,
        ^address_hash.bytes
      ),
      transaction.hash == matches.hash
    )
  end

  def where_address_fields_match(query, address_hash, nil) do
    join(
      query,
      :inner,
      [transaction],
      matches in fragment(
        """
        WITH hashes AS (
          (
            SELECT t0.hash AS hash
            FROM transactions AS t0
            WHERE t0.to_address_hash = ? OR t0.from_address_hash = ? OR t0.created_contract_address_hash = ?
          )
          UNION ALL
          (
            SELECT tt.transaction_hash AS hash
            FROM token_transfers AS tt
            WHERE tt.to_address_hash = ? OR tt.from_address_hash = ?
          )
        ) SELECT * from hashes
        """,
        ^address_hash.bytes,
        ^address_hash.bytes,
        ^address_hash.bytes,
        ^address_hash.bytes,
        ^address_hash.bytes
      ),
      transaction.hash == matches.hash
    )
  end

  @collated_fields ~w(block_number cumulative_gas_used gas_used index)a

  @collated_message "can't be blank when the transaction is collated into a block"
  @collated_field_to_check Enum.into(@collated_fields, %{}, fn collated_field ->
                             {collated_field, :"collated_#{collated_field}}"}
                           end)

  @pending_fields_with_check @collated_fields
  @pending_fields_with_validation @collated_fields ++ ~w(status)a
  @pending_message "can't be set when the transaction is pending"
  @pending_field_to_check Enum.into(@pending_fields_with_check, %{}, fn pending_field ->
                            {pending_field, :"pending_#{pending_field}}"}
                          end)

  defp check_collated(%Changeset{} = changeset) do
    check_constraints(changeset, @collated_field_to_check, @collated_message)
  end

  defp check_pending(%Changeset{} = changeset) do
    check_constraints(changeset, @pending_field_to_check, @pending_message)
  end

  @status_message "can't be blank when the internal transactions have been fetched"

  defp check_status(%Changeset{} = changeset) do
    check_constraint(changeset, :status,
      message: "can't be blank when the internal transactions have been fetched",
      name: :status
    )
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

  defp validate_collated_or_pending(%Changeset{} = changeset) do
    case Changeset.get_field(changeset, :block_hash) do
      nil -> validate_collated_or_pending(changeset, @pending_fields_with_validation, &validate_pending/2)
      %Hash{} -> validate_collated_or_pending(changeset, @collated_fields, &validate_collated/2)
    end
  end

  defp validate_collated_or_pending(%Changeset{} = changeset, fields, field_validator)
       when is_list(fields) and is_function(field_validator, 2) do
    Enum.reduce(fields, changeset, field_validator)
  end

  defp validate_pending(field, %Changeset{} = changeset) when is_atom(field) do
    case Changeset.get_field(changeset, field) do
      nil -> changeset
      _ -> Changeset.add_error(changeset, field, @pending_message)
    end
  end

  defp validate_collated(field, %Changeset{} = changeset) when is_atom(field) do
    case Changeset.get_field(changeset, field) do
      nil -> Changeset.add_error(changeset, field, @collated_message)
      _ -> changeset
    end
  end

  defp validate_status(%Changeset{} = changeset) do
    case Changeset.get_field(changeset, :internal_transactions_indexed_at) do
      nil -> changeset
      _ -> validate_required(changeset, :status, message: @status_message)
    end
  end
end
