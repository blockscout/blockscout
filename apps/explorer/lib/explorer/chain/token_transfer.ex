defmodule Explorer.Chain.TokenTransfer.Schema do
  @moduledoc """
    Models token transfers.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.TokenTransfers
  """

  alias Explorer.Chain.{
    Address,
    Block,
    Hash,
    Transaction
  }

  alias Explorer.Chain.Token.Instance

  # Remove `transaction_hash` from primary key for `:celo` chain type. See
  # `Explorer.Chain.Log.Schema` for more details.
  @transaction_field (case Application.compile_env(:explorer, :chain_type) do
                        :celo ->
                          quote do
                            [
                              belongs_to(:transaction, Transaction,
                                foreign_key: :transaction_hash,
                                references: :hash,
                                type: Hash.Full
                              )
                            ]
                          end

                        _ ->
                          quote do
                            [
                              belongs_to(:transaction, Transaction,
                                foreign_key: :transaction_hash,
                                primary_key: true,
                                references: :hash,
                                type: Hash.Full,
                                null: false
                              )
                            ]
                          end
                      end)

  defmacro generate do
    quote do
      @primary_key false
      typed_schema "token_transfers" do
        field(:amount, :decimal)
        field(:block_number, :integer) :: Block.block_number()
        field(:log_index, :integer, primary_key: true, null: false)
        field(:amounts, {:array, :decimal})
        field(:token_ids, {:array, :decimal})
        field(:token_id, :decimal, virtual: true)
        field(:index_in_batch, :integer, virtual: true)
        field(:reverse_index_in_batch, :integer, virtual: true)
        field(:token_decimals, :decimal, virtual: true)
        field(:token_type, :string)
        field(:block_consensus, :boolean)

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

        belongs_to(
          :token_contract_address,
          Address,
          foreign_key: :token_contract_address_hash,
          references: :hash,
          type: Hash.Address,
          null: false
        )

        belongs_to(:block, Block,
          foreign_key: :block_hash,
          primary_key: true,
          references: :hash,
          type: Hash.Full,
          null: false
        )

        has_many(
          :instances,
          Instance,
          foreign_key: :token_contract_address_hash,
          references: :token_contract_address_hash
        )

        has_one(:token, through: [:token_contract_address, :token])

        timestamps()

        unquote_splicing(@transaction_field)
      end
    end
  end
end

defmodule Explorer.Chain.TokenTransfer do
  @moduledoc """
  Represents a token transfer between addresses for a given token.

  ## Overview

  Token transfers are special cases from a `t:Explorer.Chain.Log.t/0`. A token
  transfer is always signified by the value from the `first_topic` in a log. That value
  is always `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef`.

  ## Data Mapping From a Log

  Here's how a log's data maps to a token transfer:

  | Log                 | Token Transfer                 | Description                     |
  |---------------------|--------------------------------|---------------------------------|
  | `:second_topic`     | `:from_address_hash`           | Address sending tokens          |
  | `:third_topic`      | `:to_address_hash`             | Address receiving tokens        |
  | `:data`             | `:amount`                      | Amount of tokens transferred    |
  | `:transaction_hash` | `:transaction_hash`            | Transaction of the transfer     |
  | `:address_hash`     | `:token_contract_address_hash` | Address of token's contract     |
  | `:index`            | `:log_index`                   | Index of log in transaction     |
  """

  use Explorer.Schema

  require Explorer.Chain.TokenTransfer.Schema

  import Ecto.Changeset

  alias Explorer.Chain
  alias Explorer.Chain.{DenormalizationHelper, Hash, Log, TokenTransfer}
  alias Explorer.{PagingOptions, Repo}

  @default_paging_options %PagingOptions{page_size: 50}

  @typep paging_options :: {:paging_options, PagingOptions.t()}
  @typep api? :: {:api?, true | false}

  @constant "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @weth_deposit_signature "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c"
  @weth_withdrawal_signature "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @erc1155_single_transfer_signature "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62"
  @erc1155_batch_transfer_signature "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb"
  @erc404_erc20_transfer_event "0xe59fdd36d0d223c0c7d996db7ad796880f45e1936cb0bb7ac102e7082e031487"
  @erc404_erc721_transfer_event "0xe5f815dc84b8cecdfd4beedfc3f91ab5be7af100eca4e8fb11552b867995394f"

  @transfer_function_signature "0xa9059cbb"

  @typedoc """
  * `:amount` - The token transferred amount
  * `:block_hash` - hash of the block
  * `:block_number` - The block number that the transfer took place.
  * `:from_address` - The `t:Explorer.Chain.Address.t/0` that sent the tokens
  * `:from_address_hash` - Address hash foreign key
  * `:to_address` - The `t:Explorer.Chain.Address.t/0` that received the tokens
  * `:to_address_hash` - Address hash foreign key
  * `:token_contract_address` - The `t:Explorer.Chain.Address.t/0` of the token's contract.
  * `:token_contract_address_hash` - Address hash foreign key
  * `:transaction` - The `t:Explorer.Chain.Transaction.t/0` ledger
  * `:transaction_hash` - Transaction foreign key
  * `:log_index` - Index of the corresponding `t:Explorer.Chain.Log.t/0` in the block.
  * `:amounts` - Tokens transferred amounts in case of batched transfer in ERC-1155
  * `:token_ids` - IDs of the tokens (applicable to ERC-1155 tokens)
  * `:token_id` - virtual field, ID of token, used to unnest ERC-1155 batch transfers
  * `:index_in_batch` - Index of the token transfer in the ERC-1155 batch transfer
  * `:reverse_index_in_batch` - Reverse index of the token transfer in the ERC-1155 batch transfer, last element index is 1
  * `:block_consensus` - Consensus of the block that the transfer took place
  """
  Explorer.Chain.TokenTransfer.Schema.generate()

  @required_attrs ~w(block_number log_index from_address_hash to_address_hash token_contract_address_hash block_hash token_type)a
                  |> (&(case Application.compile_env(:explorer, :chain_type) do
                          :celo ->
                            &1

                          _ ->
                            [:transaction_hash | &1]
                        end)).()
  @optional_attrs ~w(amount amounts token_ids block_consensus)a
                  |> (&(case Application.compile_env(:explorer, :chain_type) do
                          :celo ->
                            [:transaction_hash | &1]

                          _ ->
                            &1
                        end)).()

  @doc false
  def changeset(%TokenTransfer{} = struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:transaction)
  end

  @doc """
  Value that represents a token transfer in a `t:Explorer.Chain.Log.t/0`'s
  `first_topic` field.
  """
  def constant, do: @constant

  def weth_deposit_signature, do: @weth_deposit_signature

  def weth_withdrawal_signature, do: @weth_withdrawal_signature

  def erc1155_single_transfer_signature, do: @erc1155_single_transfer_signature

  def erc1155_batch_transfer_signature, do: @erc1155_batch_transfer_signature

  def erc404_erc20_transfer_event, do: @erc404_erc20_transfer_event

  def erc404_erc721_transfer_event, do: @erc404_erc721_transfer_event

  @doc """
  ERC 20's transfer(address,uint256) function signature
  """
  def transfer_function_signature, do: @transfer_function_signature

  @spec fetch_token_transfers_from_token_hash(Hash.t(), [paging_options | api?]) :: []
  def fetch_token_transfers_from_token_hash(token_address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        preloads =
          DenormalizationHelper.extend_transaction_preload([
            :transaction,
            :token,
            [from_address: [:names, :smart_contract, :proxy_implementations]],
            [to_address: [:scam_badge, :names, :smart_contract, :proxy_implementations]]
          ])

        only_consensus_transfers_query()
        |> where([tt], tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number))
        |> preload(^preloads)
        |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
        |> page_token_transfer(paging_options)
        |> limit(^paging_options.page_size)
        |> Chain.select_repo(options).all()
    end
  end

  @spec fetch_token_transfers_from_token_hash_and_token_id(Hash.t(), non_neg_integer(), [paging_options | api?]) :: []
  def fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        preloads =
          DenormalizationHelper.extend_transaction_preload([
            :transaction,
            :token,
            [from_address: [:names, :smart_contract, :proxy_implementations]],
            [to_address: [:scam_badge, :names, :smart_contract, :proxy_implementations]]
          ])

        only_consensus_transfers_query()
        |> where([tt], tt.token_contract_address_hash == ^token_address_hash)
        |> where([tt], fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^Decimal.new(token_id)))
        |> where([tt], not is_nil(tt.block_number))
        |> preload(^preloads)
        |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
        |> page_token_transfer(paging_options)
        |> limit(^paging_options.page_size)
        |> Chain.select_repo(options).all()
    end
  end

  @spec fetch([paging_options | api?]) :: []
  def fetch(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    token_type = Keyword.get(options, :token_type)

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        preloads =
          DenormalizationHelper.extend_transaction_preload([
            :transaction,
            :token,
            [from_address: [:names, :smart_contract, :proxy_implementations]],
            [to_address: [:names, :smart_contract, :proxy_implementations]]
          ])

        only_consensus_transfers_query()
        |> preload(^preloads)
        |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
        |> maybe_filter_by_token_type(token_type)
        |> page_token_transfer(paging_options)
        |> limit(^paging_options.page_size)
        |> Chain.select_repo(options).all()
    end
  end

  defp maybe_filter_by_token_type(query, token_types) do
    if Enum.empty?(token_types) do
      query
    else
      if DenormalizationHelper.tt_denormalization_finished?() do
        query
        |> where([tt], tt.token_type in ^token_types)
      else
        query
        |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
        |> where([tt, block, token], token.type in ^token_types)
      end
    end
  end

  @spec count_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_token_transfers_from_token_hash(token_address_hash) do
    query =
      from(
        tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^token_address_hash,
        select: fragment("COUNT(*)")
      )

    Repo.one(query, timeout: :infinity)
  end

  @spec count_token_transfers_from_token_hash_and_token_id(Hash.t(), non_neg_integer(), [api?]) :: non_neg_integer()
  def count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options) do
    query =
      from(
        tt in TokenTransfer,
        where:
          tt.token_contract_address_hash == ^token_address_hash and
            fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^Decimal.new(token_id)),
        select: fragment("COUNT(*)")
      )

    Chain.select_repo(options).one(query, timeout: :infinity)
  end

  def page_token_transfer(query, %PagingOptions{key: nil}), do: query

  def page_token_transfer(query, %PagingOptions{key: {token_id}, asc_order: true}) do
    where(query, [tt], fragment("?[1] > ?", tt.token_ids, ^token_id))
  end

  def page_token_transfer(query, %PagingOptions{key: {token_id}}) do
    where(query, [tt], fragment("?[1] < ?", tt.token_ids, ^token_id))
  end

  def page_token_transfer(query, %PagingOptions{key: {block_number, log_index}, asc_order: true}) do
    where(
      query,
      [tt],
      tt.block_number > ^block_number or (tt.block_number == ^block_number and tt.log_index > ^log_index)
    )
  end

  def page_token_transfer(query, %PagingOptions{key: {block_number, 0}}) do
    where(
      query,
      [tt],
      tt.block_number < ^block_number
    )
  end

  def page_token_transfer(query, %PagingOptions{key: {block_number, log_index}}) do
    where(
      query,
      [tt],
      tt.block_number < ^block_number or (tt.block_number == ^block_number and tt.log_index < ^log_index)
    )
  end

  def handle_paging_options(query, nil), do: query

  def handle_paging_options(query, %PagingOptions{key: nil, page_size: nil}), do: query

  def handle_paging_options(query, paging_options) do
    query
    |> page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
  end

  @doc """
  Fetches the transaction hashes from token transfers according
  to the address hash.
  """
  def where_any_address_fields_match(:to, address_hash, paging_options) do
    case paging_options do
      %PagingOptions{key: {0, _index}} ->
        []

      _ ->
        query =
          from(
            tt in TokenTransfer,
            where: tt.to_address_hash == ^address_hash,
            select: type(tt.transaction_hash, :binary),
            distinct: tt.transaction_hash
          )

        query
        |> page_transaction_hashes_from_token_transfers(paging_options)
        |> limit(^paging_options.page_size)
        |> Repo.all()
    end
  end

  def where_any_address_fields_match(:from, address_hash, paging_options) do
    case paging_options do
      %PagingOptions{key: {0, _index}} ->
        []

      _ ->
        query =
          from(
            tt in TokenTransfer,
            where: tt.from_address_hash == ^address_hash,
            select: type(tt.transaction_hash, :binary),
            distinct: tt.transaction_hash
          )

        query
        |> page_transaction_hashes_from_token_transfers(paging_options)
        |> limit(^paging_options.page_size)
        |> Repo.all()
    end
  end

  def where_any_address_fields_match(_, address_hash, paging_options) do
    {:ok, address_bytes} = Explorer.Chain.Hash.Address.dump(address_hash)

    transaction_hashes_from_token_transfers_sql(address_bytes, paging_options)
  end

  defp transaction_hashes_from_token_transfers_sql(address_bytes, %PagingOptions{page_size: page_size} = paging_options) do
    case paging_options do
      %PagingOptions{key: {0, _index}} ->
        []

      _ ->
        query =
          from(token_transfer in TokenTransfer,
            where:
              token_transfer.to_address_hash == ^address_bytes or token_transfer.from_address_hash == ^address_bytes,
            select: type(token_transfer.transaction_hash, :binary),
            distinct: token_transfer.transaction_hash,
            limit: ^page_size
          )

        query
        |> page_transaction_hashes_from_token_transfers(paging_options)
        |> Repo.all()
    end
  end

  defp page_transaction_hashes_from_token_transfers(query, %PagingOptions{key: nil}), do: query

  defp page_transaction_hashes_from_token_transfers(query, %PagingOptions{key: {block_number, _index}}) do
    where(
      query,
      [tt],
      tt.block_number < ^block_number
    )
  end

  def token_transfers_by_address_hash_and_token_address_hash(address_hash, token_address_hash) do
    only_consensus_transfers_query()
    |> where([tt], tt.from_address_hash == ^address_hash or tt.to_address_hash == ^address_hash)
    |> where([tt], tt.token_contract_address_hash == ^token_address_hash)
    |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
  end

  @doc """
  Retrieves token transfers associated with a given address, optionally filtered
  by direction and token types.

  ## Parameters

  - `address_hash` (`Hash.Address.t()`): The address hash for which to retrieve
    token transfers.
  - `direction` (`nil | :to | :from`): The direction of the transfers to filter.
    - `:to` - transfers where `to_address` matches `address_hash`.
    - `:from` - transfers where `from_address` matches `address_hash`.
    - `nil` - includes both incoming and outgoing transfers.
  - `token_types` (`[binary()]`): The token types to filter, e.g `["ERC20", "ERC721"]`.
  - `paging_options` (`nil | Explorer.PagingOptions.t()`): Pagination options to
    limit the result set.

  ## Returns

  An `Ecto.Query` for `TokenTransfer.t()`.

  ## Examples

  Fetch all incoming ERC20 token transfers for a specific address:

  # iex> query = token_transfers_by_address_hash(address_hash, :to, ["ERC20"], paging_options)
  # iex> Repo.all(query)

  Fetch both incoming and outgoing token transfers for a specific address
  without pagination, token type filtering, and direction filtering:

  # iex> query = token_transfers_by_address_hash(address_hash, nil, [], nil)
  # iex> Repo.all(query)
  """
  @spec token_transfers_by_address_hash(
          Hash.Address.t(),
          nil | :to | :from,
          [binary()],
          nil | Explorer.PagingOptions.t()
        ) :: Ecto.Query.t()
  def token_transfers_by_address_hash(address_hash, direction, token_types, paging_options) do
    if direction == :to || direction == :from do
      only_consensus_transfers_query()
      |> filter_by_direction(direction, address_hash)
      |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
      |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
      |> preload([token: token], [{:token, token}])
      |> filter_by_type(token_types)
      |> handle_paging_options(paging_options)
    else
      to_address_hash_query =
        only_consensus_transfers_query()
        |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
        |> filter_by_direction(:to, address_hash)
        |> filter_by_type(token_types)
        |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
        |> handle_paging_options(paging_options)
        |> Chain.wrapped_union_subquery()

      from_address_hash_query =
        only_consensus_transfers_query()
        |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
        |> filter_by_direction(:from, address_hash)
        |> filter_by_type(token_types)
        |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
        |> handle_paging_options(paging_options)
        |> Chain.wrapped_union_subquery()

      to_address_hash_query
      |> union(^from_address_hash_query)
      |> Chain.wrapped_union_subquery()
      |> order_by([tt], desc: tt.block_number, desc: tt.log_index)
      |> handle_paging_options(paging_options)
    end
  end

  def filter_by_direction(query, :to, address_hash) do
    query
    |> where([tt], tt.to_address_hash == ^address_hash)
  end

  def filter_by_direction(query, :from, address_hash) do
    query
    |> where([tt], tt.from_address_hash == ^address_hash)
  end

  def filter_by_type(query, []), do: query

  def filter_by_type(query, token_types) when is_list(token_types) do
    if DenormalizationHelper.tt_denormalization_finished?() do
      where(query, [tt], tt.token_type in ^token_types)
    else
      where(query, [token: token], token.type in ^token_types)
    end
  end

  def filter_by_type(query, _), do: query

  @doc """
    Returns ecto query to fetch consensus token transfers
  """
  @spec only_consensus_transfers_query() :: Ecto.Query.t()
  def only_consensus_transfers_query do
    if DenormalizationHelper.tt_denormalization_finished?() do
      from(token_transfer in __MODULE__, where: token_transfer.block_consensus == true)
    else
      from(token_transfer in __MODULE__,
        inner_join: block in assoc(token_transfer, :block),
        as: :block,
        where: block.consensus == true
      )
    end
  end

  @doc """
  Returns a list of block numbers token transfer `t:Log.t/0`s that don't have an
  associated `t:TokenTransfer.t/0` record.
  """
  @spec uncataloged_token_transfer_block_numbers :: {:ok, [non_neg_integer()]}
  def uncataloged_token_transfer_block_numbers do
    query =
      from(l in Log,
        as: :log,
        where:
          l.first_topic == ^@constant or
            l.first_topic == ^@erc1155_single_transfer_signature or
            l.first_topic == ^@erc1155_batch_transfer_signature,
        where:
          not exists(
            from(tf in TokenTransfer,
              where: tf.transaction_hash == parent_as(:log).transaction_hash,
              where: tf.log_index == parent_as(:log).index
            )
          ),
        select: l.block_number,
        distinct: l.block_number
      )

    Repo.stream_reduce(query, [], &[&1 | &2])
  end

  @doc """
    Returns ecto query to fetch consensus token transfers with ERC-721 token type
  """
  @spec erc_721_token_transfers_query() :: Ecto.Query.t()
  def erc_721_token_transfers_query do
    only_consensus_transfers_query()
    |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
    |> where([tt, token: token], token.type == "ERC-721")
    |> preload([tt, token: token], [{:token, token}])
  end

  @doc """
  To be used in migrators
  """
  @spec encode_token_transfer_ids([{Hash.t(), Hash.t(), non_neg_integer()}]) :: binary()
  def encode_token_transfer_ids(ids) do
    encoded_values =
      ids
      |> Enum.reduce("", fn {t_hash, b_hash, log_index}, acc ->
        acc <> "('#{hash_to_query_string(t_hash)}', '#{hash_to_query_string(b_hash)}', #{log_index}),"
      end)
      |> String.trim_trailing(",")

    "(#{encoded_values})"
  end

  defp hash_to_query_string(hash) do
    s_hash =
      hash
      |> to_string()
      |> String.trim_leading("0")

    "\\#{s_hash}"
  end

  @doc """
  Fetches token transfers from logs.
  """
  @spec logs_to_token_transfers([Log.t()], Keyword.t()) :: [TokenTransfer.t()]
  def logs_to_token_transfers(logs, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    logs
    |> logs_to_token_transfers_query()
    |> limit(^Enum.count(logs))
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
  end

  defp logs_to_token_transfers_query(query \\ __MODULE__, logs)

  defp logs_to_token_transfers_query(query, [log | tail]) do
    query
    |> or_where(
      [tt],
      tt.transaction_hash == ^log.transaction_hash and tt.block_hash == ^log.block_hash and tt.log_index == ^log.index
    )
    |> logs_to_token_transfers_query(tail)
  end

  defp logs_to_token_transfers_query(query, []) do
    query
  end

  @doc """
    Checks if `WHITELISTED_WETH_CONTRACTS` env contains provided address hash.
    WHITELISTED_WETH_CONTRACTS env is the list of whitelisted WETH contracts addresses.
  """
  @spec whitelisted_weth_contract?(any()) :: boolean()
  def whitelisted_weth_contract?(contract_address_hash) do
    env = Application.get_env(:explorer, Explorer.Chain.TokenTransfer)

    if env[:weth_token_transfers_filtering_enabled] do
      (contract_address_hash |> to_string() |> String.downcase()) in env[:whitelisted_weth_contracts]
    else
      true
    end
  end
end
