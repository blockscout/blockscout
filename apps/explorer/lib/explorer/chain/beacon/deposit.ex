defmodule Explorer.Chain.Beacon.Deposit do
  @moduledoc """
  Models a deposit in the beacon chain.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Data, Hash, Log, Transaction, Wei}
  alias Explorer.{Chain, Repo, SortingHelper}

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

  def changeset(deposit, attrs) do
    deposit
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  def statuses, do: @statuses_enum

  @sorting [desc: :index]

  def all(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    {required_necessity_by_association, optional_necessity_by_association} =
      options |> Keyword.get(:necessity_by_association, %{}) |> Enum.split_with(fn {_, v} -> v == :required end)

    __MODULE__
    |> SortingHelper.apply_sorting(@sorting, [])
    |> SortingHelper.page_with_sorting(paging_options, @sorting, [])
    |> Chain.join_associations(Map.new(required_necessity_by_association))
    |> Chain.select_repo(options).all()
    |> Enum.map(&put_withdrawal_address_hash/1)
    |> Chain.select_repo(options).preload(optional_necessity_by_association |> Enum.map(&elem(&1, 0)))
  end

  def from_block_hash(block_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    {required_necessity_by_association, optional_necessity_by_association} =
      options |> Keyword.get(:necessity_by_association, %{}) |> Enum.split_with(fn {_, v} -> v == :required end)

    __MODULE__
    |> where([deposit], deposit.block_hash == ^block_hash)
    |> SortingHelper.apply_sorting(@sorting, [])
    |> SortingHelper.page_with_sorting(paging_options, @sorting, [])
    |> Chain.join_associations(Map.new(required_necessity_by_association))
    |> Chain.select_repo(options).all()
    |> Enum.map(&put_withdrawal_address_hash/1)
    |> Chain.select_repo(options).preload(optional_necessity_by_association |> Enum.map(&elem(&1, 0)))
  end

  def from_address_hash(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    {required_necessity_by_association, optional_necessity_by_association} =
      options |> Keyword.get(:necessity_by_association, %{}) |> Enum.split_with(fn {_, v} -> v == :required end)

    __MODULE__
    |> where([deposit], deposit.from_address_hash == ^address_hash)
    |> SortingHelper.apply_sorting(@sorting, [])
    |> SortingHelper.page_with_sorting(paging_options, @sorting, [])
    |> Chain.join_associations(Map.new(required_necessity_by_association))
    |> Chain.select_repo(options).all()
    |> Enum.map(&put_withdrawal_address_hash/1)
    |> Chain.select_repo(options).preload(optional_necessity_by_association |> Enum.map(&elem(&1, 0)))
  end

  def get_latest_deposit(options \\ []) do
    Chain.select_repo(options).one(from(deposit in __MODULE__, order_by: [desc: deposit.index], limit: 1))
  end

  def get_logs_with_deposits(deposit_contract_address_hash, log_block_number, log_index, limit) do
    query =
      from(log in Log,
        join: transaction in assoc(log, :transaction),
        where: transaction.block_consensus == true,
        where: log.address_hash == ^deposit_contract_address_hash,
        where: log.first_topic == ^@deposit_event_signature,
        where: {log.block_number, log.index} > {^log_block_number, ^log_index},
        limit: ^limit,
        select:
          map(
            log,
            ^~w(first_topic second_topic third_topic fourth_topic data index block_number block_hash transaction_hash)a
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
