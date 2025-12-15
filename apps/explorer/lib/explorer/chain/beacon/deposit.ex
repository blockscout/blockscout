defmodule Explorer.Chain.Beacon.Deposit do
  @moduledoc """
  Models a deposit in the beacon chain.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo, SortingHelper}
  alias Explorer.Chain.{Address, Block, Data, Hash, Log, Transaction, Wei}

  @deposit_event_signature "0x649BBC62D0E31342AFEA4E5CD82D4049E7E1EE912FC0889AA790803BE39038C5"

  @required_attrs ~w(pubkey withdrawal_credentials amount signature index block_number block_timestamp log_index status from_address_hash block_hash transaction_hash)a

  @statuses_enum ~w(invalid pending completed)a

  @primary_key false
  typed_schema "beacon_deposits" do
    field(:pubkey, Data, null: false)
    field(:withdrawal_credentials, Data, null: false)
    field(:amount, Wei, null: false)
    field(:signature, Data, null: false)
    field(:index, :integer, primary_key: true)
    field(:block_number, :integer, null: false)
    field(:block_timestamp, :utc_datetime_usec, null: false)
    field(:log_index, :integer, null: false)

    field(:withdrawal_address_hash, Hash.Address, virtual: true)

    field(:status, Ecto.Enum, values: @statuses_enum, null: false)

    belongs_to(:withdrawal_address, Address,
      foreign_key: :withdrawal_address_hash,
      references: :hash,
      define_field: false
    )

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(:block, Block, foreign_key: :block_hash, references: :hash, type: Hash.Full, null: false)

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @doc """
  Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(deposit, attrs) do
    deposit
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @spec statuses :: [atom()]
  def statuses, do: @statuses_enum

  @spec event_signature :: String.t()
  def event_signature, do: @deposit_event_signature

  @sorting [desc: :index]

  @doc """
  Fetches beacon deposits with pagination and association preloading.

  Retrieves beacon deposits sorted by index in descending order (newest first).
  For each deposit, extracts the withdrawal address from the withdrawal
  credentials if they have prefix 0x01 or 0x02, making it available as a
  virtual field for association preloading.

  ## Parameters
  - `options`: A keyword list of options:
    - `:paging_options` - Pagination configuration (defaults to
      `Chain.default_paging_options()`).
    - `:necessity_by_association` - A map specifying which associations to
      preload and whether they are `:required` or `:optional`.
    - `:api?` - Boolean flag for API context.

  ## Returns
  - A list of beacon deposits with requested associations preloaded and
    withdrawal addresses extracted where applicable.
  """
  @spec all([Chain.paging_options() | Chain.necessity_by_association() | Chain.api?()]) :: [t()]
  def all(options \\ []) do
    beacon_deposits_list_query(:all, nil, options)
  end

  @doc """
  Fetches beacon deposits from a specific block with pagination and association preloading.

  Retrieves all beacon deposits that were included in the specified block,
  sorted by index in descending order (newest first). For each deposit,
  extracts the withdrawal address from the withdrawal credentials if they have
  prefix 0x01 or 0x02, making it available as a virtual field for association
  preloading.

  ## Parameters
  - `block_hash`: The hash of the block to fetch deposits from.
  - `options`: A keyword list of options:
    - `:paging_options` - Pagination configuration (defaults to
      `Chain.default_paging_options()`).
    - `:necessity_by_association` - A map specifying which associations to
      preload and whether they are `:required` or `:optional`.
    - `:api?` - Boolean flag for API context.

  ## Returns
  - A list of beacon deposits from the specified block with requested
    associations preloaded and withdrawal addresses extracted where applicable.
  """
  @spec from_block_hash(Hash.Full.t(), [Chain.paging_options() | Chain.necessity_by_association() | Chain.api?()]) :: [
          t()
        ]
  def from_block_hash(block_hash, options \\ []) do
    beacon_deposits_list_query(:block_hash, block_hash, options)
  end

  @doc """
  Fetches beacon deposits from a specific transaction with pagination and association preloading.

  Retrieves all beacon deposits that were included in the specified transaction,
  sorted by index in descending order (newest first). For each deposit,
  extracts the withdrawal address from the withdrawal credentials if they have
  prefix 0x01 or 0x02, making it available as a virtual field for association
  preloading.

  ## Parameters
  - `transaction_hash`: The hash of the transaction to fetch deposits from.
  - `options`: A keyword list of options:
    - `:paging_options` - Pagination configuration (defaults to
      `Chain.default_paging_options()`).
    - `:necessity_by_association` - A map specifying which associations to
      preload and whether they are `:required` or `:optional`.
    - `:api?` - Boolean flag for API context.

  ## Returns
  - A list of beacon deposits from the specified transaction with requested
    associations preloaded and withdrawal addresses extracted where applicable.
  """
  @spec from_transaction_hash(Hash.Full.t(), [Chain.paging_options() | Chain.necessity_by_association() | Chain.api?()]) ::
          [
            t()
          ]
  def from_transaction_hash(transaction_hash, options \\ []) do
    beacon_deposits_list_query(:transaction_hash, transaction_hash, options)
  end

  @doc """
  Fetches beacon deposits from a specific address (`from_address`) with pagination and
  association preloading.

  Retrieves all beacon deposits that were sent from the specified address,
  sorted by index in descending order (newest first). For each deposit,
  extracts the withdrawal address from the withdrawal credentials if they have
  prefix 0x01 or 0x02, making it available as a virtual field for association
  preloading.

  ## Parameters
  - `from_address`: The address hash to fetch deposits from.
  - `options`: A keyword list of options:
    - `:paging_options` - Pagination configuration (defaults to
      `Chain.default_paging_options()`).
    - `:necessity_by_association` - A map specifying which associations to
      preload and whether they are `:required` or `:optional`.
    - `:api?` - Boolean flag for API context.

  ## Returns
  - A list of beacon deposits from the specified address with requested
    associations preloaded and withdrawal addresses extracted where applicable.
  """
  @spec from_address_hash(Hash.Address.t(), [Chain.paging_options() | Chain.necessity_by_association() | Chain.api?()]) ::
          [t()]
  def from_address_hash(address_hash, options \\ []) do
    beacon_deposits_list_query(:from_address_hash, address_hash, options)
  end

  defp beacon_deposits_list_query(entity, hash, options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    {required_necessity_by_association, optional_necessity_by_association} =
      options |> Keyword.get(:necessity_by_association, %{}) |> Enum.split_with(fn {_, v} -> v == :required end)

    __MODULE__
    |> then(fn q ->
      case entity do
        :block_hash -> where(q, [deposit], deposit.block_hash == ^hash)
        :from_address_hash -> where(q, [deposit], deposit.from_address_hash == ^hash)
        :transaction_hash -> where(q, [deposit], deposit.transaction_hash == ^hash)
        :all -> q
      end
    end)
    |> SortingHelper.apply_sorting(@sorting, [])
    |> SortingHelper.page_with_sorting(paging_options, @sorting, [])
    |> Chain.join_associations(Map.new(required_necessity_by_association))
    |> Chain.select_repo(options).all()
    |> Enum.map(&put_withdrawal_address_hash/1)
    |> Chain.select_repo(options).preload(optional_necessity_by_association |> Enum.map(&elem(&1, 0)))
  end

  @doc """
  Retrieves the most recent beacon deposit by index.

  Fetches the beacon deposit with the highest index value, which represents
  the most recently indexed deposit in the system.

  ## Parameters
  - `options`: A keyword list of options:
    - `:api?` - Boolean flag for API context, determines which repository to
      use for the query.

  ## Returns
  - The beacon deposit with the highest index.
  - `nil` if no deposits exist.
  """
  @spec get_latest_deposit([Chain.api?()]) :: t() | nil
  def get_latest_deposit(options \\ []) do
    Chain.select_repo(options).one(from(deposit in __MODULE__, order_by: [desc: deposit.index], limit: 1))
  end

  @doc """
  Fetches beacon deposit event logs from the deposit contract.

  Retrieves deposit event logs from the specified deposit contract address,
  starting after the given block number and log index position. This function
  is used for paginated retrieval of deposit events, ensuring only logs from
  consensus blocks are included.

  ## Parameters
  - `deposit_contract_address_hash`: The address hash of the deposit contract.
  - `log_block_number`: The block number to start searching after (for
    pagination).
  - `log_index`: The log index within the block to start searching after (for
    pagination).
  - `limit`: The maximum number of logs to retrieve.

  ## Returns
  - A list of deposit event logs with the following fields:
    - Log fields: `first_topic`, `second_topic`, `third_topic`,
      `fourth_topic`, `data`, `index`, `block_number`, `block_hash`,
      `transaction_hash`.
    - Transaction fields: `from_address_hash`, `block_timestamp`.
  """
  @spec get_logs_with_deposits(
          Hash.Address.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [
          %{
            first_topic: Hash.Full.t(),
            data: Data.t(),
            index: non_neg_integer(),
            block_number: non_neg_integer(),
            block_hash: Hash.Full.t(),
            transaction_hash: Hash.Full.t(),
            from_address_hash: Hash.Address.t(),
            block_timestamp: DateTime.t()
          }
        ]
  def get_logs_with_deposits(deposit_contract_address_hash, log_block_number, log_index, limit) do
    query =
      from(log in Log,
        join: transaction in assoc(log, :transaction),
        where: transaction.block_consensus == true,
        where: log.block_hash == transaction.block_hash,
        where: log.address_hash == ^deposit_contract_address_hash,
        where: log.first_topic == ^@deposit_event_signature,
        where: {log.block_number, log.index} > {^log_block_number, ^log_index},
        limit: ^limit,
        select:
          map(
            log,
            ^~w(first_topic data index block_number block_hash transaction_hash)a
          ),
        order_by: [asc: log.block_number, asc: log.index],
        select_merge: map(transaction, ^~w(from_address_hash block_timestamp)a)
      )

    Repo.all(query)
  end

  defp put_withdrawal_address_hash(deposit) do
    case deposit.withdrawal_credentials do
      %Data{bytes: <<prefix, _::binary-size(11), withdrawal_address_hash_bytes::binary-size(20)>>}
      when prefix in [0x01, 0x02] ->
        {:ok, withdrawal_address_hash} = Hash.Address.cast(withdrawal_address_hash_bytes)
        Map.put(deposit, :withdrawal_address_hash, withdrawal_address_hash)

      _ ->
        deposit
    end
  end
end
