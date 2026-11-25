# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.EIP8430Transaction do
  @moduledoc """
  Models a transaction extension with the fields that only EIP-8430 transactions
  (EIP-2718 type `0x79`) have. The table has one row for each such transaction.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Data, Hash, JSONValue, Transaction}
  alias Explorer.Repo

  @optional_attrs ~w(metadata payer sender_auth payer_auth account_changes)a
  # The values that each row must have, also the row of a pending transaction.
  @pending_required_attrs ~w(transaction_hash has_named_sender nonce_key valid_after valid_before payer_type)a
  # The values from the receipt. A pending transaction has no receipt, so its row has no such values.
  @receipt_attrs ~w(resolved_payer_address_hash committed_phases_count)a
  @required_attrs @pending_required_attrs ++ @receipt_attrs

  @payer_types [:self, :open, :named, :unknown]

  @typedoc """
  The meaning of the `payer` value of the transaction:
    * `:self` - the transaction has no payer value, the sender pays.
    * `:open` - the payer is not named in the transaction. Only `resolved_payer_address_hash` contains its address.
    * `:named` - the transaction contains a payer address. It can be equal to the sender.
    * `:unknown` - the payer value has an unexpected form or is the zero address.
  """
  @type payer_type :: :self | :open | :named | :unknown

  @typedoc """
  Descriptor of the fields of an EIP-8430 transaction for import:
    * `transaction_hash` - the hash of the associated transaction.
    * `has_named_sender` - `true` if the `sender` value in the transaction object is a 20-byte address.
    * `nonce_key` - the `uint256` nonce channel.
    * `valid_after` - the lower time bound as the node returns it, in seconds or in milliseconds. `0` means no bound.
    * `valid_before` - the upper time bound as the node returns it, in seconds or in milliseconds. `0` means no bound.
    * `metadata` - opaque bytes.
    * `payer_type` - the meaning of the `payer` value.
    * `payer` - the `payer` value of the node without change. It is not the resolved payer, see `resolved_payer_address_hash`.
    * `sender_auth` - the authorization bytes of the sender.
    * `payer_auth` - the authorization bytes of the payer.
    * `account_changes` - the account changes in the form that the node returns.
    * `resolved_payer_address_hash` - the address of the resolved payer from the receipt: the account that pays the fee.
      `nil` for a transaction that was imported as pending and is not mined.
    * `committed_phases_count` - the number of call phases that committed, from the receipt.
      `nil` for a transaction that was imported as pending and is not mined.
  """
  @type to_import :: %{
          transaction_hash: binary(),
          has_named_sender: boolean(),
          nonce_key: non_neg_integer() | nil,
          valid_after: non_neg_integer() | nil,
          valid_before: non_neg_integer() | nil,
          metadata: binary() | nil,
          payer_type: payer_type(),
          payer: binary() | nil,
          sender_auth: binary() | nil,
          payer_auth: binary() | nil,
          account_changes: JSONValue.t(),
          resolved_payer_address_hash: binary() | nil,
          committed_phases_count: non_neg_integer() | nil
        }

  @typedoc """
    * `transaction_hash` - the hash of the associated transaction.
    * `has_named_sender` - `true` if the `sender` value in the transaction object is a 20-byte address.
    * `nonce_key` - the `uint256` nonce channel.
    * `valid_after` - the lower time bound as the node returns it, in seconds or in milliseconds. `0` means no bound.
    * `valid_before` - the upper time bound as the node returns it, in seconds or in milliseconds. `0` means no bound.
    * `metadata` - opaque bytes.
    * `payer_type` - the meaning of the `payer` value.
    * `payer` - the `payer` value of the node without change. It is not the resolved payer, see `resolved_payer_address_hash`.
    * `sender_auth` - the authorization bytes of the sender.
    * `payer_auth` - the authorization bytes of the payer.
    * `account_changes` - the account changes in the form that the node returns.
    * `resolved_payer_address_hash` - the address of the resolved payer from the receipt: the account that pays the fee.
      `nil` for a transaction that was imported as pending and is not mined.
    * `committed_phases_count` - the number of call phases that committed, from the receipt.
      `nil` for a transaction that was imported as pending and is not mined.
    * `inserted_at` - timestamp indicating when the row was created.
    * `updated_at` - timestamp indicating when the row was last updated.
    * `transaction` - an instance of `Explorer.Chain.Transaction` referenced by `transaction_hash`.
  """
  @primary_key false
  typed_schema "eip_8430_transactions" do
    field(:has_named_sender, :boolean, null: false)
    field(:nonce_key, :decimal, null: false)
    field(:valid_after, :decimal, null: false)
    field(:valid_before, :decimal, null: false)
    field(:metadata, Data)
    field(:payer_type, Ecto.Enum, values: @payer_types, null: false)
    field(:payer, Data)
    field(:sender_auth, Data)
    field(:payer_auth, Data)
    field(:account_changes, JSONValue)
    field(:resolved_payer_address_hash, Hash.Address)
    field(:committed_phases_count, :integer)

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @doc """
    Validates the `attrs` of the row of a mined transaction.

    The receipt values `resolved_payer_address_hash` and `committed_phases_count` are
    required. The block import uses this function, so it rejects a row without them.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction_hash)
  end

  @doc """
    Validates the `attrs` of the row of a pending transaction.

    A pending transaction has no receipt, so the receipt values
    `resolved_payer_address_hash` and `committed_phases_count` are not required. All other
    rules are the same as in `changeset/2`. `Indexer.Fetcher.PendingTransaction` selects this
    function with the `with: :pending_changeset` option of `Explorer.Chain.import/1`.
  """
  @spec pending_changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def pending_changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@pending_required_attrs)
    |> foreign_key_constraint(:transaction_hash)
  end

  @doc """
    Returns the `nonce_key` values of the given transactions.

    The `nonce_key` is the nonce channel of an EIP-8430 transaction. The result has an entry
    only for a transaction that has a row in `eip_8430_transactions`. For an empty list, the
    function sends no query.

    ## Parameters
    - `transaction_hashes`: The hashes of the transactions.

    ## Returns
    A map from the transaction hash to the `nonce_key` of the transaction.
  """
  @spec transaction_hashes_to_nonce_keys([Hash.Full.t()]) :: %{Hash.Full.t() => Decimal.t()}
  def transaction_hashes_to_nonce_keys([]), do: %{}

  def transaction_hashes_to_nonce_keys(transaction_hashes) when is_list(transaction_hashes) do
    query =
      from(eip_8430_transaction in __MODULE__,
        where: eip_8430_transaction.transaction_hash in ^transaction_hashes,
        select: {eip_8430_transaction.transaction_hash, eip_8430_transaction.nonce_key}
      )

    query
    |> Repo.all()
    |> Map.new()
  end
end
