defmodule Explorer.Chain.AdvancedFilter do
  @moduledoc """
  Models an advanced filter.
  """

  use Explorer.Schema

  import Ecto.Query
  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  alias Explorer.{Chain, Helper, PagingOptions}
  alias Explorer.Helper, as: ExplorerHelper

  alias Explorer.Chain.{
    Address,
    Address.Reputation,
    Data,
    DenormalizationHelper,
    Hash,
    InternalTransaction,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader

  @primary_key false
  typed_embedded_schema null: false do
    field(:hash, Hash.Full)
    field(:type, :string)
    field(:input, Data)
    field(:timestamp, :utc_datetime_usec)

    field(:status) ::
      :pending
      | :awaiting_internal_transactions
      | :success
      | {:error, :awaiting_internal_transactions}
      | {:error, reason :: String.t()}

    field(:created_from, Ecto.Enum, values: [:transaction, :internal_transaction, :token_transfer])

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address
    )

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

    field(:value, :decimal, null: true)

    has_one(:token_transfer, TokenTransfer, foreign_key: :transaction_hash, references: :hash, null: true)

    field(:fee, :decimal)

    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:internal_transaction_index, :integer, null: true)
    field(:token_transfer_index, :integer, null: true)
    field(:token_transfer_batch_index, :integer, null: true)
  end

  @typep transaction_types :: {:transaction_types, [String.t()] | nil}
  @typep methods :: {:methods, [String.t()] | nil}
  @typep age :: {:age, [{:from, DateTime.t() | nil} | {:to, DateTime.t() | nil}] | nil}
  @typep from_address_hashes :: {:from_address_hashes, [Hash.Address.t()] | nil}
  @typep to_address_hashes :: {:to_address_hashes, [Hash.Address.t()] | nil}
  @typep address_relation :: {:address_relation, :or | :and | nil}
  @typep amount :: {:amount, [{:from, Decimal.t()} | {:to, Decimal.t()}] | nil}
  @typep token_contract_address_hashes ::
           {:token_contract_address_hashes, [{:include, [Hash.Address.t()]} | {:include, [Hash.Address.t()]}] | nil}
  @type options :: [
          transaction_types()
          | methods()
          | age()
          | from_address_hashes()
          | to_address_hashes()
          | address_relation()
          | amount()
          | token_contract_address_hashes()
          | Chain.paging_options()
          | Chain.api?()
          | {:timeout, timeout()}
        ]

  @spec list(options()) :: [t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options)

    timeout = Keyword.get(options, :timeout, :timer.seconds(60))

    age = Keyword.get(options, :age)

    block_numbers_age =
      [
        from:
          age[:from] &&
            BlockGeneralReader.timestamp_to_block_number(
              age[:from],
              :after,
              Keyword.get(options, :api?, false)
            ),
        to:
          age[:to] &&
            BlockGeneralReader.timestamp_to_block_number(
              age[:to],
              :before,
              Keyword.get(options, :api?, false)
            )
      ]

    tasks =
      options
      |> Keyword.put(:block_numbers_age, block_numbers_age)
      |> query_functions(paging_options)
      |> Enum.map(fn query_function ->
        Task.async(fn -> query_function.(Chain.select_repo(options), timeout: timeout) end)
      end)

    tasks
    |> Task.yield_many(timeout: timeout, on_timeout: :kill_task)
    |> Enum.flat_map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching advanced filters terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching advanced filters timed out."
      end
    end)
    |> Enum.map(&to_advanced_filter/1)
    |> Enum.sort(&sort_function/2)
    |> take_page_size(paging_options)
    |> Chain.select_repo(options).preload(
      from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()],
      to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()],
      created_contract_address: [:names, :smart_contract, proxy_implementations_association()]
    )
    |> sanitize_fee()
    |> assign_type()
    |> Enum.to_list()
  end

  defp query_functions(options, paging_options) do
    []
    |> maybe_add_transactions_queries(options, paging_options)
    |> maybe_add_token_transfers_queries(options, paging_options)
  end

  @transaction_types ["COIN_TRANSFER", "CONTRACT_INTERACTION", "CONTRACT_CREATION"]
  defp maybe_add_transactions_queries(query_functions, options, paging_options) do
    transaction_types = options[:transaction_types] || []
    tokens_to_include = options[:token_contract_address_hashes][:include] || []
    tokens_to_exclude = options[:token_contract_address_hashes][:exclude] || []

    if (transaction_types == [] or Enum.any?(@transaction_types, &Enum.member?(transaction_types, &1))) and
         (tokens_to_include == [] or "native" in tokens_to_include) and
         "native" not in tokens_to_exclude do
      [
        transactions_query_function(paging_options, options),
        internal_transactions_query_function(paging_options, options) | query_functions
      ]
    else
      query_functions
    end
  end

  defp maybe_add_token_transfers_queries(query_functions, options, paging_options) do
    transaction_types = options[:transaction_types] || []
    tokens_to_include = options[:token_contract_address_hashes][:include] || []

    if (transaction_types == [] or not (transaction_types |> Enum.reject(&(&1 in @transaction_types)) |> Enum.empty?())) and
         (tokens_to_include == [] or not (tokens_to_include |> Enum.reject(&(&1 == "native")) |> Enum.empty?())) do
      [token_transfers_query_function(paging_options, options) | query_functions]
    else
      query_functions
    end
  end

  defp sanitize_fee(advanced_filters) do
    Stream.scan(advanced_filters, fn
      %__MODULE__{hash: hash, created_from: created_from} = advanced_filter, %__MODULE__{hash: hash}
      when created_from != :internal_transaction ->
        %__MODULE__{advanced_filter | fee: Decimal.new(0)}

      advanced_filter, _ ->
        advanced_filter
    end)
  end

  defp assign_type(advanced_filters) do
    Stream.map(advanced_filters, fn advanced_filter ->
      type =
        cond do
          advanced_filter.created_from in ~w(transaction internal_transaction)a and
              is_nil(advanced_filter.to_address_hash) ->
            "contract_creation"

          advanced_filter.created_from in ~w(transaction internal_transaction)a and
              not is_nil(advanced_filter.to_address.contract_code) ->
            "contract_interaction"

          advanced_filter.created_from in ~w(transaction internal_transaction)a ->
            "coin_transfer"

          true ->
            advanced_filter.token_transfer.token_type
        end

      %{advanced_filter | type: type}
    end)
  end

  defp to_advanced_filter(%Transaction{} = transaction) do
    %{value: decimal_transaction_value} = transaction.value

    %__MODULE__{
      hash: transaction.hash,
      created_from: :transaction,
      input: transaction.input,
      timestamp: transaction.block_timestamp,
      status: Chain.transaction_to_status(transaction),
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      created_contract_address_hash: transaction.created_contract_address_hash,
      value: decimal_transaction_value,
      fee: transaction |> Transaction.fee(:wei) |> elem(1),
      block_number: transaction.block_number,
      transaction_index: transaction.index
    }
  end

  defp to_advanced_filter(%InternalTransaction{} = internal_transaction) do
    %__MODULE__{
      hash: internal_transaction.transaction.hash,
      created_from: :internal_transaction,
      input: internal_transaction.input,
      timestamp: internal_transaction.transaction.block_timestamp,
      status: Chain.transaction_to_status(internal_transaction.transaction),
      from_address_hash: internal_transaction.from_address_hash,
      to_address_hash: internal_transaction.to_address_hash,
      created_contract_address_hash: internal_transaction.created_contract_address_hash,
      value: (internal_transaction.value && internal_transaction.value.value) || Decimal.new(0),
      fee:
        internal_transaction.transaction.gas_price && internal_transaction.gas_used &&
          Decimal.mult(internal_transaction.transaction.gas_price.value, internal_transaction.gas_used),
      block_number: internal_transaction.transaction.block_number,
      transaction_index: internal_transaction.transaction.index,
      internal_transaction_index: internal_transaction.index
    }
  end

  defp to_advanced_filter(%TokenTransfer{} = token_transfer) do
    %__MODULE__{
      hash: token_transfer.transaction.hash,
      created_from: :token_transfer,
      input: token_transfer.transaction.input,
      timestamp: token_transfer.transaction.block_timestamp,
      status: Chain.transaction_to_status(token_transfer.transaction),
      from_address_hash: token_transfer.from_address_hash,
      to_address_hash: token_transfer.to_address_hash,
      created_contract_address_hash: nil,
      fee: token_transfer.transaction |> Transaction.fee(:wei) |> elem(1),
      token_transfer: %TokenTransfer{
        token_transfer
        | amounts: [token_transfer.amount],
          token_ids: token_transfer.token_id && [token_transfer.token_id]
      },
      block_number: token_transfer.block_number,
      transaction_index: token_transfer.transaction.index,
      token_transfer_index: token_transfer.log_index,
      token_transfer_batch_index: token_transfer.reverse_index_in_batch
    }
  end

  defp sort_function(a, b) do
    case {
      Helper.compare(a.block_number, b.block_number),
      Helper.compare(a.transaction_index, b.transaction_index),
      Helper.compare(a.token_transfer_index, b.token_transfer_index),
      Helper.compare(a.token_transfer_batch_index, b.token_transfer_batch_index),
      Helper.compare(a.internal_transaction_index, b.internal_transaction_index)
    } do
      {:lt, _, _, _, _} ->
        false

      {:eq, :lt, _, _, _} ->
        false

      {:eq, :eq, _, _, _} ->
        case {a.token_transfer_index, a.token_transfer_batch_index, a.internal_transaction_index,
              b.token_transfer_index, b.token_transfer_batch_index, b.internal_transaction_index} do
          {nil, _, nil, _, _, _} ->
            true

          {a_tt_index, a_tt_batch_index, nil, b_tt_index, b_tt_batch_index, _} when not is_nil(b_tt_index) ->
            {a_tt_index, a_tt_batch_index} > {b_tt_index, b_tt_batch_index}

          {nil, _, a_it_index, _, _, b_it_index} ->
            a_it_index > b_it_index

          {_, _, _, _, _, _} ->
            false
        end

      _ ->
        true
    end
  end

  defp take_page_size(list, %PagingOptions{page_size: page_size}) when is_integer(page_size) do
    Enum.take(list, page_size)
  end

  defp take_page_size(list, _), do: list

  defp transactions_query_function(paging_options, options) do
    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(transaction in Transaction,
          as: :transaction,
          where: transaction.block_consensus == true,
          order_by: [
            desc: transaction.block_number,
            desc: transaction.index
          ]
        )
      else
        from(transaction in Transaction,
          as: :transaction,
          join: block in assoc(transaction, :block),
          as: :block,
          where: block.consensus == true,
          order_by: [
            desc: transaction.block_number,
            desc: transaction.index
          ]
        )
      end

    filtered_and_paginated_query =
      query
      |> page_transactions(paging_options)
      |> limit_query(paging_options)
      |> apply_transactions_filters(
        options,
        fn query -> query |> order_by([transaction], desc: transaction.block_number, desc: transaction.index) end
      )
      |> limit_query(paging_options)

    fn repo, repo_options -> repo.all(filtered_and_paginated_query, repo_options) end
  end

  defp page_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:transaction, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index)
      )

    query |> where(^dynamic_condition)
  end

  defp page_transactions(query, _), do: query

  defp internal_transactions_query_function(paging_options, options) do
    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(internal_transaction in InternalTransaction,
          as: :internal_transaction,
          join: transaction in assoc(internal_transaction, :transaction),
          as: :transaction,
          where: transaction.block_consensus == true,
          where:
            (internal_transaction.type == :call and internal_transaction.index > 0) or
              internal_transaction.type != :call,
          order_by: [
            desc: transaction.block_number,
            desc: transaction.index,
            desc: internal_transaction.index
          ]
        )
      else
        from(internal_transaction in InternalTransaction,
          as: :internal_transaction,
          join: transaction in assoc(internal_transaction, :transaction),
          as: :transaction,
          join: block in assoc(internal_transaction, :block),
          as: :block,
          where: block.consensus == true,
          where:
            (internal_transaction.type == :call and internal_transaction.index > 0) or
              internal_transaction.type != :call,
          order_by: [
            desc: transaction.block_number,
            desc: transaction.index,
            desc: internal_transaction.index
          ]
        )
      end

    filtered_and_paginated_query =
      query
      |> page_internal_transactions(paging_options)
      |> limit_query(paging_options)
      |> apply_transactions_filters(options, fn query ->
        query
        |> order_by([internal_transaction],
          desc: internal_transaction.block_number,
          desc: internal_transaction.transaction_index,
          desc: internal_transaction.index
        )
      end)
      |> limit_query(paging_options)
      |> preload([:transaction])

    fn repo, repo_options -> repo.all(filtered_and_paginated_query, repo_options) end
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: _transaction_index,
           internal_transaction_index: nil
         }
       })
       when block_number < 0 do
    query |> where(false)
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           internal_transaction_index: nil
         }
       })
       when block_number > 0 and transaction_index <= 0 do
    query |> where(as(:transaction).block_number < ^block_number)
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: 0,
           transaction_index: 0,
           internal_transaction_index: nil
         }
       }) do
    query |> where(as(:transaction).block_number == 0 and as(:transaction).index == 0)
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: 0,
           transaction_index: transaction_index,
           internal_transaction_index: nil
         }
       }) do
    query
    |> where(as(:transaction).block_number == 0 and as(:transaction).index <= ^transaction_index)
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           internal_transaction_index: nil
         }
       }) do
    query
    |> where(
      as(:transaction).block_number < ^block_number or
        (as(:transaction).block_number == ^block_number and as(:transaction).index <= ^transaction_index)
    )
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           internal_transaction_index: it_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:transaction, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index) or
          ^page_it_index_dynamic(block_number, transaction_index, it_index)
      )

    query
    |> where(^dynamic_condition)
  end

  defp page_internal_transactions(query, _), do: query

  defp token_transfers_query_function(paging_options, options) do
    token_transfer_query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(token_transfer in TokenTransfer,
          as: :token_transfer,
          join: transaction in assoc(token_transfer, :transaction),
          as: :transaction,
          join: token in assoc(token_transfer, :token),
          as: :token,
          select: %TokenTransfer{
            token_transfer
            | token_id: fragment("UNNEST(?)", token_transfer.token_ids),
              amount:
                fragment("UNNEST(COALESCE(?, ARRAY[COALESCE(?, 1)]))", token_transfer.amounts, token_transfer.amount),
              reverse_index_in_batch:
                fragment("GENERATE_SERIES(COALESCE(ARRAY_LENGTH(?, 1), 1), 1, -1)", token_transfer.amounts),
              token_decimals: token.decimals
          },
          where: transaction.block_consensus == true,
          order_by: [
            desc: token_transfer.block_number,
            desc: token_transfer.log_index
          ]
        )
      else
        from(token_transfer in TokenTransfer,
          as: :token_transfer,
          join: transaction in assoc(token_transfer, :transaction),
          as: :transaction,
          join: token in assoc(token_transfer, :token),
          as: :token,
          join: block in assoc(token_transfer, :block),
          as: :block,
          select: %TokenTransfer{
            token_transfer
            | token_id: fragment("UNNEST(?)", token_transfer.token_ids),
              amount:
                fragment("UNNEST(COALESCE(?, ARRAY[COALESCE(?, 1)]))", token_transfer.amounts, token_transfer.amount),
              reverse_index_in_batch:
                fragment("GENERATE_SERIES(COALESCE(ARRAY_LENGTH(?, 1), 1), 1, -1)", token_transfer.amounts),
              token_decimals: token.decimals
          },
          where: block.consensus == true,
          order_by: [
            desc: token_transfer.block_number,
            desc: token_transfer.log_index
          ]
        )
      end

    query_function =
      (&make_token_transfer_query_unnested/2)
      |> apply_token_transfers_filters(options)
      |> page_token_transfers(paging_options)

    filtered_and_paginated_query =
      token_transfer_query
      |> ExplorerHelper.maybe_hide_scam_addresses_for_token_transfers(options)
      |> limit_query(paging_options)
      |> query_function.(false)
      |> limit_query(paging_options)
      |> select_merge([unnested_token_transfer: unnested_token_transfer], %{
        token_ids: [unnested_token_transfer.token_id],
        amounts: [unnested_token_transfer.amount]
      })

    fn repo, repo_options ->
      filtered_and_paginated_query
      |> repo.all(repo_options)
      |> repo.preload([:transaction, [token: Reputation.reputation_association()]])
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: _transaction_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       })
       when block_number < 0 do
    fn query, unnested? ->
      query |> where(false) |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       })
       when block_number > 0 and transaction_index <= 0 do
    fn query, unnested? ->
      query |> where([token_transfer], token_transfer.block_number < ^block_number) |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: 0,
           transaction_index: 0,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    fn query, unnested? ->
      query
      |> where(as(:transaction).block_number == 0 and as(:transaction).index == 0)
      |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: 0,
           transaction_index: transaction_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    fn query, unnested? ->
      query
      |> where(
        [token_transfer],
        token_transfer.block_number == 0 and as(:transaction).index < ^transaction_index
      )
      |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    fn query, unnested? ->
      query
      |> where(
        [token_transfer],
        token_transfer.block_number < ^block_number or
          (token_transfer.block_number == ^block_number and as(:transaction).index <= ^transaction_index)
      )
      |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           token_transfer_index: nil
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:token_transfer, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index)
      )

    fn query, unnested? ->
      query |> where(^dynamic_condition) |> query_function.(unnested?)
    end
  end

  defp page_token_transfers(query_function, %PagingOptions{
         key: %{
           block_number: block_number,
           token_transfer_index: tt_index,
           token_transfer_batch_index: tt_batch_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:token_transfer, block_number) or
          ^page_tt_index_dynamic(:token_transfer, block_number, tt_index, tt_batch_index)
      )

    fn query, unnested? ->
      query
      |> where(^dynamic_condition)
      |> query_function.(unnested?)
      |> where(
        ^page_tt_batch_index_dynamic(
          block_number,
          tt_index,
          tt_batch_index
        )
      )
    end
  end

  defp page_token_transfers(query_function, _), do: query_function

  defp page_block_number_dynamic(binding, block_number) when block_number > 0 do
    dynamic(as(^binding).block_number < ^block_number)
  end

  defp page_block_number_dynamic(_, _) do
    dynamic(false)
  end

  defp page_transaction_index_dynamic(block_number, transaction_index)
       when block_number >= 0 and transaction_index > 0 do
    dynamic(
      [transaction: transaction],
      transaction.block_number == ^block_number and transaction.index < ^transaction_index
    )
  end

  defp page_transaction_index_dynamic(_, _) do
    dynamic(false)
  end

  defp page_it_index_dynamic(block_number, transaction_index, it_index)
       when block_number >= 0 and transaction_index >= 0 and it_index > 0 do
    dynamic(
      [transaction: transaction, internal_transaction: it],
      transaction.block_number == ^block_number and transaction.index == ^transaction_index and
        it.index < ^it_index
    )
  end

  defp page_it_index_dynamic(_, _, _) do
    dynamic(false)
  end

  defp page_tt_index_dynamic(binding, block_number, tt_index, tt_batch_index)
       when block_number >= 0 and tt_index > 0 and tt_batch_index > 1 do
    dynamic(as(^binding).block_number == ^block_number and as(^binding).log_index <= ^tt_index)
  end

  defp page_tt_index_dynamic(binding, block_number, tt_index, _tt_batch_index)
       when block_number >= 0 and tt_index > 0 do
    dynamic(as(^binding).block_number == ^block_number and as(^binding).log_index < ^tt_index)
  end

  defp page_tt_index_dynamic(_, _, _, _) do
    dynamic(false)
  end

  defp page_tt_batch_index_dynamic(block_number, tt_index, tt_batch_index)
       when block_number >= 0 and tt_index >= 0 and tt_batch_index > 1 do
    dynamic(
      [unnested_token_transfer: tt],
      ^page_block_number_dynamic(:unnested_token_transfer, block_number) or
        ^page_tt_index_dynamic(
          :unnested_token_transfer,
          block_number,
          tt_index,
          0
        ) or
        (tt.block_number == ^block_number and tt.log_index == ^tt_index and tt.reverse_index_in_batch < ^tt_batch_index)
    )
  end

  defp page_tt_batch_index_dynamic(_, _, _) do
    dynamic(true)
  end

  defp limit_query(query, %PagingOptions{page_size: limit}) when is_integer(limit), do: limit(query, ^limit)

  defp limit_query(query, _), do: query

  defp apply_token_transfers_filters(query_function, options) do
    query_function
    |> filter_token_transfer_by_types(options[:transaction_types])
    |> filter_token_transfers_by_methods(
      options[:methods],
      [include: nil, exclude: nil] == options[:from_address_hashes] and
        options[:to_address_hashes] == [include: nil, exclude: nil]
    )
    |> filter_token_transfers_by_age(options)
    |> filter_by_token(options[:token_contract_address_hashes])
    |> filter_token_transfers_by_addresses(
      options[:from_address_hashes],
      options[:to_address_hashes],
      options[:address_relation]
    )
    |> filter_token_transfers_by_amount(options[:amount][:from], options[:amount][:to])
  end

  defp apply_transactions_filters(query, options, order_by) do
    query
    |> filter_transaction_by_types(options[:transaction_types])
    |> filter_transactions_by_amount(options[:amount][:from], options[:amount][:to])
    |> filter_transactions_by_methods(options[:methods])
    |> only_collated_transactions()
    |> filter_by_age(:transaction, options)
    |> filter_transactions_by_addresses(
      options[:from_address_hashes],
      options[:to_address_hashes],
      options[:address_relation],
      order_by
    )
  end

  defp only_collated_transactions(query) do
    query |> where(not is_nil(as(:transaction).block_number) and not is_nil(as(:transaction).index))
  end

  defp filter_transaction_by_types(query, types) when types in [nil, []], do: query

  defp filter_transaction_by_types(query, types) do
    if Enum.all?(@transaction_types, &Enum.member?(types, &1)) do
      query
    else
      dynamic_condition =
        types
        |> Enum.reduce(nil, fn
          type, dynamic_condition when type in @transaction_types ->
            filter_transaction_by_type(type, dynamic_condition)

          _, dynamic_condition ->
            dynamic_condition
        end)

      query =
        if "CONTRACT_INTERACTION" in types and not has_named_binding?(query, :to_address) do
          join(query, :left, [t], a in assoc(t, :to_address), as: :to_address)
        else
          query
        end

      query |> where(^dynamic_condition)
    end
  end

  defp filter_transaction_by_type("COIN_TRANSFER", nil), do: dynamic([t], t.value > ^0)

  defp filter_transaction_by_type("COIN_TRANSFER", dynamic_condition),
    do: dynamic([t], t.value > ^0 or ^dynamic_condition)

  defp filter_transaction_by_type("CONTRACT_INTERACTION", nil),
    do: dynamic([to_address: to_address], not is_nil(to_address.contract_code))

  defp filter_transaction_by_type("CONTRACT_INTERACTION", dynamic_condition),
    do: dynamic([to_address: to_address], not is_nil(to_address.contract_code) or ^dynamic_condition)

  defp filter_transaction_by_type("CONTRACT_CREATION", nil), do: dynamic([t], is_nil(t.to_address_hash))

  defp filter_transaction_by_type("CONTRACT_CREATION", dynamic_condition),
    do: dynamic([t], is_nil(t.to_address_hash) or ^dynamic_condition)

  defp filter_token_transfer_by_types(query_function, [_ | _] = types) do
    types = types -- @transaction_types

    if DenormalizationHelper.tt_denormalization_finished?() do
      fn query, unnested? ->
        query |> where([token_transfer], token_transfer.token_type in ^types) |> query_function.(unnested?)
      end
    else
      fn query, unnested? ->
        query |> where([token: token], token.type in ^types) |> query_function.(unnested?)
      end
    end
  end

  defp filter_token_transfer_by_types(query_function, _), do: query_function

  defp filter_transactions_by_methods(query, [_ | _] = methods) do
    prepared_methods = prepare_methods(methods)

    query |> where([t], fragment("substring(? FOR 4)", t.input) in ^prepared_methods)
  end

  defp filter_transactions_by_methods(query, _), do: query

  defp filter_token_transfers_by_methods(query_function, [_ | _] = methods, true) do
    fn query, _unnested? ->
      from(
        method_ids in fragment("SELECT unnest(?) as method_id", type(^methods, {:array, Data})),
        as: :method_ids,
        cross_lateral_join:
          token_transfer in subquery(
            query
            |> where(fragment("substring(? FOR 4)", as(:transaction).input) == parent_as(:method_ids).method_id)
            |> exclude(:order_by)
            |> order_by(
              desc: as(:transaction).block_number,
              desc: as(:transaction).index,
              desc: as(:token_transfer).log_index
            )
            |> query_function.(true)
          ),
        as: :unnested_token_transfer,
        select: token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp filter_token_transfers_by_methods(query_function, [_ | _] = methods, false) do
    prepared_methods = prepare_methods(methods)

    fn query, unnested? ->
      query
      |> where(fragment("substring(? FOR 4)", as(:transaction).input) in ^prepared_methods)
      |> query_function.(unnested?)
    end
  end

  defp filter_token_transfers_by_methods(query_function, _, _), do: query_function

  defp prepare_methods(methods) do
    methods
    |> Enum.flat_map(fn
      method ->
        case Data.cast(method) do
          {:ok, method} -> [method.bytes]
          _ -> []
        end
    end)
  end

  defp filter_token_transfers_by_age(query_function, options) do
    fn query, unnested? -> query |> filter_by_age(:token_transfer, options) |> query_function.(unnested?) end
  end

  defp filter_by_age(query, entity, options) do
    query
    |> do_filter_by_age(options[:block_numbers_age][:from], options[:age][:from], entity, :from)
    |> do_filter_by_age(options[:block_numbers_age][:to], options[:age][:to], entity, :to)
  end

  defp do_filter_by_age(query, {:ok, block_number}, _timestamp, entity, direction) do
    filter_by_block_number(query, block_number, entity, direction)
  end

  defp do_filter_by_age(query, _block_number, timestamp, _entity, direction) do
    filter_by_timestamp(query, timestamp, direction)
  end

  defp filter_by_block_number(query, from, entity, :from) when not is_nil(from) do
    query |> where(as(^entity).block_number >= ^from)
  end

  defp filter_by_block_number(query, to, entity, :to) when not is_nil(to) do
    query |> where(as(^entity).block_number <= ^to)
  end

  defp filter_by_block_number(query, _, _, _), do: query

  defp filter_by_timestamp(query, %DateTime{} = from, :from) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      query |> where(as(:transaction).block_timestamp >= ^from)
    else
      query |> where(as(:block).timestamp >= ^from)
    end
  end

  defp filter_by_timestamp(query, %DateTime{} = to, :to) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      query |> where(as(:transaction).block_timestamp <= ^to)
    else
      query |> where(as(:block).timestamp <= ^to)
    end
  end

  defp filter_by_timestamp(query, _, _), do: query

  defp filter_token_transfers_by_addresses(query_function, from_addresses_params, to_addresses_params, relation) do
    case {process_address_inclusion(from_addresses_params), process_address_inclusion(to_addresses_params)} do
      {nil, nil} -> query_function
      {from, nil} -> do_filter_token_transfers_by_address(query_function, from, :from_address_hash)
      {nil, to} -> do_filter_token_transfers_by_address(query_function, to, :to_address_hash)
      {from, to} -> do_filter_token_transfers_by_both_addresses(query_function, from, to, relation)
    end
  end

  defp do_filter_token_transfers_by_address(query_function, {:include, addresses}, field) do
    fn query, _unnested? ->
      queries =
        addresses
        |> Enum.map(fn address ->
          query |> where([token_transfer], field(token_transfer, ^field) == ^address) |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_address(query_function, {:exclude, addresses}, field) do
    fn query, unnested? ->
      query |> where([t], field(t, ^field) not in ^addresses) |> query_function.(unnested?)
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:include, from}, {:include, to}, :and) do
    fn query, unnested? ->
      query |> where([t], t.from_address_hash in ^from and t.to_address_hash in ^to) |> query_function.(unnested?)
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:include, from}, {:include, to}, _relation) do
    fn query, _unnested? ->
      from_queries =
        from
        |> Enum.map(fn from_address ->
          query |> where([token_transfer], token_transfer.from_address_hash == ^from_address) |> query_function.(true)
        end)

      to_queries =
        to
        |> Enum.map(fn to_address ->
          query |> where([token_transfer], token_transfer.to_address_hash == ^to_address) |> query_function.(true)
        end)

      union_query =
        from_queries
        |> Kernel.++(to_queries)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union(acc, ^query) end)

      from(token_transfer in subquery(union_query),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:include, from}, {:exclude, to}, :and) do
    fn query, _unnested? ->
      from_queries =
        from
        |> Enum.map(fn from_address ->
          query
          |> where(
            [token_transfer],
            token_transfer.from_address_hash == ^from_address and token_transfer.to_address_hash not in ^to
          )
          |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(from_queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:include, from}, {:exclude, to}, _relation) do
    fn query, _unnested? ->
      from_queries =
        from
        |> Enum.map(fn from_address ->
          query
          |> where(
            [token_transfer],
            token_transfer.from_address_hash == ^from_address or token_transfer.to_address_hash not in ^to
          )
          |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(from_queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:exclude, from}, {:include, to}, :and) do
    fn query, _unnested? ->
      to_queries =
        to
        |> Enum.map(fn to_address ->
          query
          |> where(
            [token_transfer],
            token_transfer.to_address_hash == ^to_address and token_transfer.from_address_hash not in ^from
          )
          |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(to_queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:exclude, from}, {:include, to}, _relation) do
    fn query, _unnested? ->
      to_queries =
        to
        |> Enum.map(fn to_address ->
          query
          |> where(
            [token_transfer],
            token_transfer.to_address_hash == ^to_address or token_transfer.from_address_hash not in ^from
          )
          |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(to_queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:exclude, from}, {:exclude, to}, :and) do
    fn query, unnested? ->
      query
      |> where([t], t.from_address_hash not in ^from and t.to_address_hash not in ^to)
      |> query_function.(unnested?)
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query_function, {:exclude, from}, {:exclude, to}, _relation) do
    fn query, unnested? ->
      query
      |> where([t], t.from_address_hash not in ^from or t.to_address_hash not in ^to)
      |> query_function.(unnested?)
    end
  end

  defp filter_transactions_by_addresses(query, from_addresses, to_addresses, relation, order_by) do
    order_by = fn query -> query |> exclude(:order_by) |> order_by.() end

    case {process_address_inclusion(from_addresses), process_address_inclusion(to_addresses)} do
      {nil, nil} -> query
      {from, nil} -> do_filter_transactions_by_address(query, from, :from_address_hash, order_by)
      {nil, to} -> do_filter_transactions_by_address(query, to, :to_address_hash, order_by)
      {from, to} -> do_filter_transactions_by_both_addresses(query, from, to, relation, order_by)
    end
  end

  defp do_filter_transactions_by_address(query, {:include, addresses}, field, order_by) do
    queries =
      addresses
      |> Enum.map(fn address ->
        query
        |> where([transaction], field(transaction, ^field) == ^address)
        |> order_by.()
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    filtered_query = from(transaction in subquery(queries))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_address(query, {:exclude, addresses}, field, order_by) do
    query
    |> where([transaction], field(transaction, ^field) not in ^addresses)
    |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:include, from}, {:include, to}, :and, order_by) do
    query
    |> where([transaction], transaction.from_address_hash in ^from and transaction.to_address_hash in ^to)
    |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:include, from}, {:include, to}, _relation, order_by) do
    from_queries =
      from
      |> Enum.map(fn from_address ->
        query
        |> where([transaction], transaction.from_address_hash == ^from_address)
        |> order_by.()
      end)

    to_queries =
      to
      |> Enum.map(fn to_address ->
        query
        |> where([transaction], transaction.to_address_hash == ^to_address)
        |> order_by.()
      end)

    union_query =
      from_queries
      |> Kernel.++(to_queries)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union(acc, ^query) end)

    filtered_query = from(transaction in subquery(union_query))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:include, from}, {:exclude, to}, :and, order_by) do
    from_queries =
      from
      |> Enum.map(fn from_address ->
        query
        |> where(
          [transaction],
          transaction.from_address_hash == ^from_address and transaction.to_address_hash not in ^to
        )
        |> order_by.()
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    filtered_query = from(transaction in subquery(from_queries))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:include, from}, {:exclude, to}, _relation, order_by) do
    from_queries =
      from
      |> Enum.map(fn from_address ->
        query
        |> where(
          [transaction],
          transaction.from_address_hash == ^from_address or transaction.to_address_hash not in ^to
        )
        |> order_by.()
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    filtered_query = from(transaction in subquery(from_queries))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:exclude, from}, {:include, to}, :and, order_by) do
    to_queries =
      to
      |> Enum.map(fn to_address ->
        query
        |> where(
          [transaction],
          transaction.to_address_hash == ^to_address and transaction.from_address_hash not in ^from
        )
        |> order_by.()
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    filtered_query = from(transaction in subquery(to_queries))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:exclude, from}, {:include, to}, _relation, order_by) do
    to_queries =
      to
      |> Enum.map(fn to_address ->
        query
        |> where(
          [transaction],
          transaction.to_address_hash == ^to_address or transaction.from_address_hash not in ^from
        )
        |> order_by.()
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    filtered_query = from(transaction in subquery(to_queries))
    filtered_query |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:exclude, from}, {:exclude, to}, :and, order_by) do
    query
    |> where(
      [transaction],
      transaction.from_address_hash not in ^from and transaction.to_address_hash not in ^to
    )
    |> order_by.()
  end

  defp do_filter_transactions_by_both_addresses(query, {:exclude, from}, {:exclude, to}, _relation, order_by) do
    query
    |> where(
      [transaction],
      transaction.from_address_hash not in ^from or transaction.to_address_hash not in ^to
    )
    |> order_by.()
  end

  @eth_decimals 1_000_000_000_000_000_000

  defp filter_transactions_by_amount(query, from, to) when not is_nil(from) and not is_nil(to) do
    if Decimal.positive?(to) and Decimal.lt?(from, to) do
      query |> where([t], t.value / @eth_decimals >= ^from and t.value / @eth_decimals <= ^to)
    else
      query |> where(false)
    end
  end

  defp filter_transactions_by_amount(query, _from, to) when not is_nil(to) do
    if Decimal.positive?(to) do
      query |> where([t], t.value / @eth_decimals <= ^to)
    else
      query |> where(false)
    end
  end

  defp filter_transactions_by_amount(query, from, _to) when not is_nil(from) do
    if Decimal.positive?(from) do
      query |> where([t], t.value / @eth_decimals >= ^from)
    else
      query
    end
  end

  defp filter_transactions_by_amount(query, _, _), do: query

  defp filter_token_transfers_by_amount(query_function, from, to) do
    fn query, unnested? ->
      query
      |> filter_token_transfers_by_amount_before_subquery(from, to)
      |> query_function.(unnested?)
      |> filter_token_transfers_by_amount_after_subquery(from, to)
    end
  end

  defp filter_token_transfers_by_amount_before_subquery(query, from, to)
       when not is_nil(from) and not is_nil(to) and from < to do
    if Decimal.positive?(to) and Decimal.lt?(from, to) do
      query
      |> where(
        [tt, token: token],
        ^to * fragment("10 ^ COALESCE(?, 0)", token.decimals) >=
          fragment("ANY(COALESCE(?, ARRAY[COALESCE(?, 1)]))", tt.amounts, tt.amount) and
          ^from * fragment("10 ^ COALESCE(?, 0)", token.decimals) <=
            fragment("ANY(COALESCE(?, ARRAY[COALESCE(?, 1)]))", tt.amounts, tt.amount)
      )
    else
      query |> where(false)
    end
  end

  defp filter_token_transfers_by_amount_before_subquery(query, _from, to) when not is_nil(to) do
    if Decimal.positive?(to) do
      query
      |> where(
        [tt, token: token],
        ^to * fragment("10 ^ COALESCE(?, 0)", token.decimals) >=
          fragment("ANY(COALESCE(?, ARRAY[COALESCE(?, 1)]))", tt.amounts, tt.amount)
      )
    else
      query |> where(false)
    end
  end

  defp filter_token_transfers_by_amount_before_subquery(query, from, _to) when not is_nil(from) do
    if Decimal.positive?(from) do
      query
      |> where(
        [tt, token: token],
        ^from * fragment("10 ^ COALESCE(?, 0)", token.decimals) <=
          fragment("ANY(COALESCE(?, ARRAY[COALESCE(?, 1)]))", tt.amounts, tt.amount)
      )
    else
      query
    end
  end

  defp filter_token_transfers_by_amount_before_subquery(query, _, _), do: query

  defp filter_token_transfers_by_amount_after_subquery(unnested_query, from, to)
       when not is_nil(from) and not is_nil(to) and from < to do
    if Decimal.positive?(to) and Decimal.lt?(from, to) do
      unnested_query
      |> where(
        [unnested_token_transfer: tt],
        tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) >= ^from and
          tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) <= ^to
      )
    else
      unnested_query |> where(false)
    end
  end

  defp filter_token_transfers_by_amount_after_subquery(unnested_query, _from, to) when not is_nil(to) do
    if Decimal.positive?(to) do
      unnested_query
      |> where(
        [unnested_token_transfer: tt],
        tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) <= ^to
      )
    else
      unnested_query |> where(false)
    end
  end

  defp filter_token_transfers_by_amount_after_subquery(unnested_query, from, _to) when not is_nil(from) do
    if Decimal.positive?(from) do
      unnested_query
      |> where(
        [unnested_token_transfer: tt],
        tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) >= ^from
      )
    else
      unnested_query
    end
  end

  defp filter_token_transfers_by_amount_after_subquery(query, _, _), do: query

  defp make_token_transfer_query_unnested(query, false) do
    with_named_binding(query, :unnested_token_transfer, fn query, binding ->
      from(token_transfer in subquery(query),
        as: ^binding
      )
    end)
  end

  defp make_token_transfer_query_unnested(query, _), do: query

  defp filter_by_token(query_function, token_contract_address_hashes) when is_list(token_contract_address_hashes) do
    case process_address_inclusion(token_contract_address_hashes) do
      nil ->
        query_function

      {include_or_exclude, token_contract_address_hashes} ->
        filtered = token_contract_address_hashes |> Enum.reject(&(&1 == "native"))

        if Enum.empty?(filtered) do
          query_function
        else
          do_filter_by_token(query_function, {include_or_exclude, filtered})
        end
    end
  end

  defp filter_by_token(query_function, _), do: query_function

  defp do_filter_by_token(query_function, {:include, token_contract_address_hashes}) do
    fn query, _unnested? ->
      queries =
        token_contract_address_hashes
        |> Enum.map(fn address ->
          query
          |> where([token_transfer], token_transfer.token_contract_address_hash == ^address)
          |> query_function.(true)
        end)
        |> map_first(&subquery/1)
        |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

      from(token_transfer in subquery(queries),
        as: :unnested_token_transfer,
        order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
      )
    end
  end

  defp do_filter_by_token(query_function, {:exclude, token_contract_address_hashes}) do
    fn query, unnested? ->
      query_function.(
        from(token_transfer in query,
          left_join: to_exclude in fragment("UNNEST(?)", type(^token_contract_address_hashes, {:array, Hash.Address})),
          on: token_transfer.token_contract_address_hash == to_exclude,
          where: is_nil(to_exclude)
        ),
        unnested?
      )
    end
  end

  defp process_address_inclusion(addresses) when is_list(addresses) do
    case {Keyword.get(addresses, :include, []), Keyword.get(addresses, :exclude, [])} do
      {to_include, to_exclude} when to_include in [nil, []] and to_exclude in [nil, []] ->
        nil

      {to_include, to_exclude} when to_include in [nil, []] and is_list(to_exclude) ->
        {:exclude, to_exclude}

      {to_include, to_exclude} when is_list(to_include) ->
        case to_include -- (to_exclude || []) do
          [] -> nil
          to_include -> {:include, to_include}
        end
    end
  end

  defp process_address_inclusion(_), do: nil

  defp map_first([h | t], f), do: [f.(h) | t]
  defp map_first([], _f), do: []
end
