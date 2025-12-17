defmodule Explorer.Stats.HotSmartContracts do
  @moduledoc """
  This module defines the HotSmartContracts schema and functions for aggregating and paginating hot contracts.
  """
  use Explorer.Schema

  alias Explorer.{Chain, PagingOptions, SortingHelper}
  alias Explorer.Chain.{Address, Block, Hash, Transaction}
  alias Explorer.Chain.Block.Reader.General, as: BlockReaderGeneral
  alias Explorer.Helper, as: ExplorerHelper

  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]
  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  @primary_key false
  typed_schema "hot_smart_contracts_daily" do
    field(:date, :date, primary_key: true)
    field(:contract_address_hash, Hash.Address, primary_key: true)
    field(:transactions_count, :integer)
    field(:total_gas_used, :decimal)

    belongs_to(:contract_address, Address,
      foreign_key: :contract_address_hash,
      references: :hash,
      type: Hash.Address,
      define_field: false
    )

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, [:date, :contract_address_hash, :transactions_count, :total_gas_used])
    |> validate_required([:date, :contract_address_hash, :transactions_count, :total_gas_used])
  end

  @spec aggregate_hot_smart_contracts_for_date(Date.t(), keyword()) ::
          {:ok,
           [%{contract_address_hash: Hash.Address.t(), transactions_count: integer(), total_gas_used: Decimal.t()}]}
          | {:error, any()}
  def aggregate_hot_smart_contracts_for_date(date, options \\ []) do
    with {:ok, from_date} <- DateTime.new(date, ~T[00:00:00], "Etc/UTC"),
         {:ok, to_date} <- date |> Date.add(1) |> DateTime.new(~T[00:00:00], "Etc/UTC"),
         {:ok, from_block} <-
           BlockReaderGeneral.timestamp_to_block_number(from_date, :after, options[:api?] || false, true),
         {:ok, to_block} <-
           BlockReaderGeneral.timestamp_to_block_number(to_date, :before, options[:api?] || false, true) do
      {:ok,
       from_block
       |> aggregate_hot_smart_contracts_for_block_interval_query(to_block)
       |> Chain.select_repo(options).all(timeout: :infinity)
       |> Enum.map(&Map.put(&1, :date, date))}
    else
      error -> {:error, error}
    end
  end

  @spec aggregate_hot_smart_contracts_for_block_interval_query(Block.block_number(), Block.block_number()) ::
          Ecto.Query.t()
  defp aggregate_hot_smart_contracts_for_block_interval_query(from_block, to_block) do
    from(transaction in Transaction,
      as: :transaction,
      where: transaction.block_number >= ^from_block and transaction.block_number <= ^to_block,
      inner_join: address in assoc(transaction, :to_address),
      as: :to_address,
      where: not is_nil(address.contract_code),
      group_by: transaction.to_address_hash,
      select: %{
        contract_address_hash: selected_as(transaction.to_address_hash, :contract_address_hash),
        transactions_count: selected_as(count(), :transactions_count),
        total_gas_used: selected_as(sum(transaction.gas_used), :total_gas_used)
      }
    )
  end

  @spec indexed_dates(keyword()) :: [Date.t()]
  def indexed_dates(options \\ []) do
    __MODULE__
    |> select([hot_smart_contracts_daily], hot_smart_contracts_daily.date)
    |> distinct(true)
    |> Chain.select_repo(options).all(timeout: :infinity)
  end

  @spec delete_older_than(Date.t(), keyword()) :: {non_neg_integer(), nil}
  def delete_older_than(date, options \\ []) do
    __MODULE__
    |> where([hot_smart_contracts_daily], hot_smart_contracts_daily.date < ^date)
    |> Chain.select_repo(options).delete_all(timeout: :infinity)
  end

  @doc """
  Paginate hot contracts by scale.

  ## Parameters
  - `scale`: Time interval to aggregate hot contracts on (5m, 1h, 3h, 1d, 7d, 30d).
  - `options`: The options to pass to the paginated function.

  ## Returns
  - A list of hot contracts.
  """
  @spec paginated(String.t(), keyword()) :: [__MODULE__.t()] | {:error, :not_found}
  def paginated(scale, options \\ []) do
    case scale do
      "5m" -> last_n_seconds_paginated(300, options)
      "1h" -> last_n_seconds_paginated(3600, options)
      "3h" -> last_n_seconds_paginated(10800, options)
      "1d" -> last_n_days_paginated(1, options)
      "7d" -> last_n_days_paginated(7, options)
      "30d" -> last_n_days_paginated(30, options)
      _ -> raise "Invalid scale: #{scale}"
    end
  end

  defp last_n_seconds_paginated(n, options) do
    default_sorting = [
      {:dynamic, :transactions_count, :desc_nulls_last, transactions_count_on_transactions_dynamic()},
      {:dynamic, :total_gas_used, :desc_nulls_last, total_gas_used_on_transactions_dynamic()},
      {:asc, :to_address_hash, :transaction}
    ]

    paging_options = Keyword.get(options, :paging_options, PagingOptions.default_paging_options())
    sorting_options = Keyword.get(options, :sorting, %{})[:aggregated_on_transactions] || []

    preloads =
      Keyword.get(options, :preloads,
        contract_address: [:smart_contract, :names, proxy_implementations_association(), reputation_association()]
      )

    now = DateTime.utc_now()
    from_timestamp = DateTime.add(now, -n, :second)

    with {:ok, from_block} <-
           BlockReaderGeneral.timestamp_to_block_number(from_timestamp, :after, options[:api?] || false, true),
         {:ok, to_block} <-
           BlockReaderGeneral.timestamp_to_block_number(now, :before, options[:api?] || false, true) do
      from_block
      |> aggregate_hot_smart_contracts_for_block_interval_query(to_block)
      |> ExplorerHelper.maybe_hide_scam_addresses(:to_address_hash, options)
      |> SortingHelper.apply_sorting(sorting_options, default_sorting)
      |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting)
      |> Chain.select_repo(options).all()
      |> Enum.map(&struct(__MODULE__, &1))
      |> Chain.select_repo(options).preload(preloads)
    end
  end

  defp last_n_days_paginated(n, options) do
    default_sorting = [
      {:dynamic, :transactions_count, :desc_nulls_last, transactions_count_dynamic()},
      {:dynamic, :total_gas_used, :desc_nulls_last, total_gas_used_dynamic()},
      asc: :contract_address_hash
    ]

    paging_options = Keyword.get(options, :paging_options, PagingOptions.default_paging_options())
    sorting_options = Keyword.get(options, :sorting, %{})[:aggregated_on_hot_smart_contracts] || []

    preloads =
      Keyword.get(options, :preloads,
        contract_address: [:smart_contract, :names, proxy_implementations_association(), reputation_association()]
      )

    __MODULE__
    |> where([hot_smart_contracts_daily], hot_smart_contracts_daily.date >= ^Date.add(Date.utc_today(), -n))
    |> ExplorerHelper.maybe_hide_scam_addresses(:contract_address_hash, options)
    |> group_by([hot_smart_contracts_daily], hot_smart_contracts_daily.contract_address_hash)
    |> select([hot_smart_contracts_daily], %{
      contract_address_hash: hot_smart_contracts_daily.contract_address_hash,
      transactions_count: sum(hot_smart_contracts_daily.transactions_count),
      total_gas_used: sum(hot_smart_contracts_daily.total_gas_used)
    })
    |> SortingHelper.apply_sorting(sorting_options, default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting)
    |> Chain.select_repo(options).all()
    |> Enum.map(&struct(__MODULE__, &1))
    |> Chain.select_repo(options).preload(preloads)
  end

  @spec transactions_count_dynamic() :: Ecto.Query.dynamic_expr()
  def transactions_count_dynamic do
    dynamic([hot_smart_contracts_daily], sum(hot_smart_contracts_daily.transactions_count))
  end

  @spec total_gas_used_dynamic() :: Ecto.Query.dynamic_expr()
  def total_gas_used_dynamic do
    dynamic([hot_smart_contracts_daily], sum(hot_smart_contracts_daily.total_gas_used))
  end

  @spec transactions_count_on_transactions_dynamic() :: Ecto.Query.dynamic_expr()
  def transactions_count_on_transactions_dynamic do
    dynamic([transaction], count())
  end

  @spec total_gas_used_on_transactions_dynamic() :: Ecto.Query.dynamic_expr()
  def total_gas_used_on_transactions_dynamic do
    dynamic([transaction], sum(transaction.gas_used))
  end
end
