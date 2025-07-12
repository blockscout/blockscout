defmodule BlockScoutWeb.Chain do
  @moduledoc """
  Converts the `param` to the corresponding resource that uses that format of param.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Explorer.Chain,
    only: [
      hash_to_block: 1,
      hash_to_transaction: 1,
      number_to_block: 1,
      string_to_address_hash: 1,
      string_to_full_hash: 1
    ]

  import Explorer.PagingOptions,
    only: [
      default_paging_options: 0,
      page_size: 0
    ]

  import Explorer.Helper, only: [parse_boolean: 1, parse_integer: 1]

  alias BlockScoutWeb.PagingHelper
  alias Ecto.Association.NotLoaded
  alias Explorer.Account.{TagAddress, TagTransaction, WatchlistAddress}
  alias Explorer.Chain.Beacon.Reader, as: BeaconReader

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CurrentTokenBalance,
    Beacon.Blob,
    Block,
    Block.Reward,
    Hash,
    InternalTransaction,
    Log,
    Search,
    SmartContract,
    Token,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Transaction.StateChange,
    UserOperation,
    Wei,
    Withdrawal
  }

  alias Explorer.Chain.Optimism.Deposit, as: OptimismDeposit
  alias Explorer.Chain.Optimism.FrameSequence, as: OptimismFrameSequence
  alias Explorer.Chain.Optimism.InteropMessage, as: OptimismInteropMessage
  alias Explorer.Chain.Optimism.OutputRoot, as: OptimismOutputRoot
  alias Explorer.Chain.Scroll.Bridge, as: ScrollBridge
  alias Explorer.PagingOptions

  defimpl Poison.Encoder, for: Decimal do
    def encode(value, _opts) do
      # silence the xref warning
      decimal = Decimal

      [?\", decimal.to_string(value), ?\"]
    end
  end

  @page_size page_size()
  @default_paging_options default_paging_options()
  @address_hash_len 40
  @full_hash_len 64

  def current_filter(%{paging_options: paging_options} = params) do
    params
    |> (&(Map.get(&1, "filter") || Map.get(&1, :filter))).()
    |> case do
      "to" -> [direction: :to, paging_options: paging_options]
      "from" -> [direction: :from, paging_options: paging_options]
      _ -> [paging_options: paging_options]
    end
  end

  def current_filter(params) do
    params
    |> (&(Map.get(&1, "filter") || Map.get(&1, :filter))).()
    |> case do
      "to" -> [direction: :to]
      "from" -> [direction: :from]
      _ -> []
    end
  end

  @spec from_param(String.t()) ::
          {:ok, Address.t() | Block.t() | Transaction.t() | UserOperation.t() | Blob.t()} | {:error, :not_found}
  def from_param(param)

  def from_param("0x" <> number_string = param) when byte_size(number_string) == @address_hash_len,
    do: address_from_param(param)

  def from_param("0x" <> number_string = param) when byte_size(number_string) == @full_hash_len,
    do: block_or_transaction_or_operation_or_blob_from_param(param)

  def from_param(param) when byte_size(param) == @address_hash_len,
    do: address_from_param("0x" <> param)

  def from_param(param) when byte_size(param) == @full_hash_len,
    do: block_or_transaction_or_operation_or_blob_from_param("0x" <> param)

  if @chain_type == :filecoin do
    def from_param(string) when is_binary(string) do
      case param_to_block_number(string) do
        {:ok, number} ->
          number_to_block(number)

        _ ->
          case Search.maybe_parse_filecoin_address(string) do
            {:ok, filecoin_address} ->
              result =
                filecoin_address
                |> Search.address_by_filecoin_id_or_robust()
                # credo:disable-for-next-line Credo.Check.Design.AliasUsage
                |> Explorer.Chain.select_repo(api?: true).one()

              (result && {:ok, result}) || {:error, :not_found}

            _ ->
              search_ens_domain(string)
          end
      end
    end
  else
    def from_param(string) when is_binary(string) do
      case param_to_block_number(string) do
        {:ok, number} ->
          number_to_block(number)

        _ ->
          search_ens_domain(string)
      end
    end
  end

  @spec next_page_params(any, list(), map(), (any -> map())) :: nil | map
  def next_page_params(next_page, list, params, paging_function \\ &paging_params/1)

  def next_page_params([], _list, _params, _), do: nil

  def next_page_params(_, list, params, paging_function) do
    paging_params = paging_function.(List.last(list))

    next_page_params = Map.merge(params, paging_params)
    current_items_count_string = Map.get(next_page_params, "items_count")

    items_count =
      if is_binary(current_items_count_string) do
        {current_items_count, _} = Integer.parse(current_items_count_string)
        current_items_count + Enum.count(list)
      else
        Enum.count(list)
      end

    Map.put(next_page_params, "items_count", items_count)
  end

  @doc """
    Makes Explorer.PagingOptions map. Overloaded by different params in the input map
    for different modules using this function.
  """
  @spec paging_options(any) ::
          [{:paging_options, Explorer.PagingOptions.t()}, ...] | Explorer.PagingOptions.t()
  def paging_options(%{
        hash: hash_string,
        fetched_coin_balance: fetched_coin_balance_string,
        transactions_count: transactions_count_string
      })
      when is_binary(hash_string) do
    case string_to_address_hash(hash_string) do
      {:ok, address_hash} ->
        [
          paging_options: %{
            @default_paging_options
            | key: %{
                fetched_coin_balance: decimal_parse(fetched_coin_balance_string),
                hash: address_hash,
                transactions_count: parse_integer(transactions_count_string)
              }
          }
        ]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        fee: fee_string,
        value: value_string,
        block_number: block_number_string,
        index: index_string,
        inserted_at: inserted_at,
        hash: hash_string
      }) do
    case string_to_full_hash(hash_string) do
      {:ok, hash} ->
        [
          paging_options: %{
            @default_paging_options
            | key: %{
                fee: decimal_parse(fee_string),
                value: decimal_parse(value_string),
                block_number: parse_integer(block_number_string),
                index: parse_integer(index_string),
                inserted_at: inserted_at,
                hash: hash
              }
          }
        ]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(
        %{
          "market_cap" => market_cap_string,
          "holders_count" => holder_count_string,
          # todo: It should be removed in favour `holders_count` property with the next release after 8.0.0
          "holder_count" => holder_count_string,
          "name" => name_string,
          "contract_address_hash" => contract_address_hash_string,
          "is_name_null" => is_name_null_string
        } = params
      )
      when is_binary(market_cap_string) and is_binary(holder_count_string) and is_binary(name_string) and
             is_binary(contract_address_hash_string) and is_binary(is_name_null_string) do
    market_cap_decimal = decimal_parse(market_cap_string)

    fiat_value_decimal = decimal_parse(params["fiat_value"])

    holder_count = parse_integer(holder_count_string)
    token_name = if is_name_null_string == "true", do: nil, else: name_string

    case Hash.Address.cast(contract_address_hash_string) do
      {:ok, contract_address_hash} ->
        [
          paging_options: %{
            @default_paging_options
            | key: %{
                fiat_value: fiat_value_decimal,
                circulating_market_cap: market_cap_decimal,
                holder_count: holder_count,
                name: token_name,
                contract_address_hash: contract_address_hash
              }
          }
        ]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        "block_number" => block_number_string,
        "transaction_index" => transaction_index_string,
        "index" => index_string
      })
      when is_binary(block_number_string) and is_binary(transaction_index_string) and is_binary(index_string) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {transaction_index, ""} <- Integer.parse(transaction_index_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, transaction_index, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        block_number: block_number,
        transaction_index: transaction_index,
        index: index
      }) do
    [paging_options: %{@default_paging_options | key: {block_number, transaction_index, index}}]
  end

  def paging_options(%{
        "block_number" => block_number_string,
        "index" => index_string,
        "batch_log_index" => batch_log_index_string,
        "batch_block_hash" => batch_block_hash_string,
        "batch_transaction_hash" => batch_transaction_hash_string,
        "index_in_batch" => index_in_batch_string
      })
      when is_binary(block_number_string) and is_binary(index_string) and is_binary(batch_log_index_string) and
             is_binary(batch_block_hash_string) and is_binary(batch_transaction_hash_string) and
             is_binary(index_in_batch_string) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {index, ""} <- Integer.parse(index_string),
         {index_in_batch, ""} <- Integer.parse(index_in_batch_string),
         {:ok, batch_transaction_hash} <- string_to_full_hash(batch_transaction_hash_string),
         {:ok, batch_block_hash} <- string_to_full_hash(batch_block_hash_string),
         {batch_log_index, ""} <- Integer.parse(batch_log_index_string) do
      [
        paging_options: %{
          @default_paging_options
          | key: {block_number, index},
            batch_key: {batch_block_hash, batch_transaction_hash, batch_log_index, index_in_batch}
        }
      ]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        "batch_log_index" => batch_log_index_string,
        "batch_block_hash" => batch_block_hash_string,
        "batch_transaction_hash" => batch_transaction_hash_string,
        "index_in_batch" => index_in_batch_string
      })
      when is_binary(batch_log_index_string) and is_binary(batch_block_hash_string) and
             is_binary(batch_transaction_hash_string) and is_binary(index_in_batch_string) do
    with {index_in_batch, ""} <- Integer.parse(index_in_batch_string),
         {:ok, batch_transaction_hash} <- string_to_full_hash(batch_transaction_hash_string),
         {:ok, batch_block_hash} <- string_to_full_hash(batch_block_hash_string),
         {batch_log_index, ""} <- Integer.parse(batch_log_index_string) do
      [
        paging_options: %{
          @default_paging_options
          | batch_key: {batch_block_hash, batch_transaction_hash, batch_log_index, index_in_batch}
        }
      ]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        block_number: block_number,
        index: index,
        batch_log_index: batch_log_index,
        batch_block_hash: batch_block_hash_string,
        batch_transaction_hash: batch_transaction_hash_string,
        index_in_batch: index_in_batch
      })
      when is_binary(batch_transaction_hash_string) and is_binary(batch_block_hash_string) do
    with {:ok, batch_transaction_hash} <- string_to_full_hash(batch_transaction_hash_string),
         {:ok, batch_block_hash} <- string_to_full_hash(batch_block_hash_string) do
      [
        paging_options: %{
          @default_paging_options
          | key: {block_number, index},
            batch_key: {batch_block_hash, batch_transaction_hash, batch_log_index, index_in_batch}
        }
      ]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        batch_log_index: batch_log_index,
        batch_block_hash: batch_block_hash_string,
        batch_transaction_hash: batch_transaction_hash_string,
        index_in_batch: index_in_batch
      })
      when is_binary(batch_block_hash_string) and
             is_binary(batch_transaction_hash_string) do
    with {:ok, batch_transaction_hash} <- string_to_full_hash(batch_transaction_hash_string),
         {:ok, batch_block_hash} <- string_to_full_hash(batch_block_hash_string) do
      [
        paging_options: %{
          @default_paging_options
          | batch_key: {batch_block_hash, batch_transaction_hash, batch_log_index, index_in_batch}
        }
      ]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"block_number" => block_number_string, "index" => index_string})
      when is_binary(block_number_string) and is_binary(index_string) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{block_number: block_number, index: index}) do
    [paging_options: %{@default_paging_options | key: {block_number, index}}]
  end

  def paging_options(%{"block_number" => block_number_string}) when is_binary(block_number_string) do
    case Integer.parse(block_number_string) do
      {block_number, ""} ->
        [paging_options: %{@default_paging_options | key: {block_number}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{block_number: block_number}) do
    [paging_options: %{@default_paging_options | key: {block_number}}]
  end

  def paging_options(%{"index" => index_string}) when is_binary(index_string) do
    case Integer.parse(index_string) do
      {index, ""} ->
        [paging_options: %{@default_paging_options | key: {index}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"index" => index}) when is_integer(index) do
    [paging_options: %{@default_paging_options | key: {index}}]
  end

  def paging_options(%{index: index}) do
    [paging_options: %{@default_paging_options | key: {index}}]
  end

  def paging_options(%{"nonce" => nonce_string}) when is_binary(nonce_string) do
    case Integer.parse(nonce_string) do
      {nonce, ""} ->
        [paging_options: %{@default_paging_options | key: {nonce}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"number" => number_string}) when is_binary(number_string) do
    case Integer.parse(number_string) do
      {number, ""} ->
        [paging_options: %{@default_paging_options | key: {number}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"nonce" => nonce}) when is_integer(nonce) do
    [paging_options: %{@default_paging_options | key: {nonce}}]
  end

  def paging_options(%{"number" => number}) when is_integer(number) do
    [paging_options: %{@default_paging_options | key: {number}}]
  end

  def paging_options(%{"inserted_at" => inserted_at_string, "hash" => hash_string})
      when is_binary(inserted_at_string) and is_binary(hash_string) do
    with {:ok, inserted_at, _} <- DateTime.from_iso8601(inserted_at_string),
         {:ok, hash} <- string_to_full_hash(hash_string) do
      [paging_options: %{@default_paging_options | key: {inserted_at, hash}, is_pending_transaction: true}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{inserted_at: inserted_at, hash: hash_string}) when is_binary(hash_string) do
    case string_to_full_hash(hash_string) do
      {:ok, hash} ->
        [paging_options: %{@default_paging_options | key: {inserted_at, hash}, is_pending_transaction: true}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"token_name" => name, "token_type" => type, "token_inserted_at" => inserted_at}),
    do: [paging_options: %{@default_paging_options | key: {name, type, inserted_at}}]

  def paging_options(%{"value" => value, "address_hash" => address_hash}) do
    [paging_options: %{@default_paging_options | key: {value, address_hash}}]
  end

  def paging_options(%{"fiat_value" => fiat_value_string, "value" => value_string, "id" => id_string})
      when is_binary(fiat_value_string) and is_binary(value_string) and is_binary(id_string) do
    with {id, ""} <- Integer.parse(id_string),
         {value, ""} <- Decimal.parse(value_string),
         {_id, _value, {fiat_value, ""}} <- {id, value, Decimal.parse(fiat_value_string)} do
      [paging_options: %{@default_paging_options | key: {fiat_value, value, id}}]
    else
      {id, value, :error} ->
        [paging_options: %{@default_paging_options | key: {nil, value, id}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{fiat_value: fiat_value_string, value: value_string, id: id})
      when is_binary(fiat_value_string) and is_binary(value_string) do
    with {value, ""} <- Decimal.parse(value_string),
         {_id, _value, {fiat_value, ""}} <- {id, value, Decimal.parse(fiat_value_string)} do
      [paging_options: %{@default_paging_options | key: {fiat_value, value, id}}]
    else
      {id, value, :error} ->
        [paging_options: %{@default_paging_options | key: {nil, value, id}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"value" => value_string, "id" => id_string})
      when is_binary(value_string) and is_binary(id_string) do
    with {id, ""} <- Integer.parse(id_string),
         {value, ""} <- Decimal.parse(value_string) do
      [paging_options: %{@default_paging_options | key: {nil, value, id}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"items_count" => items_count_string, "state_changes" => _}) when is_binary(items_count_string) do
    case Integer.parse(items_count_string) do
      {count, ""} -> [paging_options: %{@default_paging_options | key: {count}}]
      _ -> @default_paging_options
    end
  end

  def paging_options(%{"l1_block_number" => block_number, "transaction_hash" => transaction_hash}) do
    with {block_number, ""} <- Integer.parse(block_number),
         {:ok, transaction_hash} <- string_to_full_hash(transaction_hash) do
      [paging_options: %{@default_paging_options | key: {block_number, transaction_hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  # clause for pagination of entities:
  # - Account's entities
  # - Optimism frame sequences
  # - Polygon Edge Deposits
  # - Polygon Edge Withdrawals
  # - Arbitrum cross chain messages
  # - Scroll cross chain messages
  def paging_options(%{"id" => id_string}) when is_binary(id_string) do
    case Integer.parse(id_string) do
      {id, ""} ->
        [paging_options: %{@default_paging_options | key: {id}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"timestamp" => timestamp, "init_transaction_hash" => init_transaction_hash}) do
    with {ts, ""} <- Integer.parse(timestamp),
         {:ok, transaction_hash} <- string_to_full_hash(init_transaction_hash) do
      [paging_options: %{@default_paging_options | key: {ts, transaction_hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  # clause for pagination of entities:
  # - Account's entities
  # - Optimism frame sequences
  # - Polygon Edge Deposits
  # - Polygon Edge Withdrawals
  # - Arbitrum cross chain messages
  # - Scroll cross chain messages
  def paging_options(%{"id" => id}) when is_integer(id) do
    [paging_options: %{@default_paging_options | key: {id}}]
  end

  def paging_options(%{
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id,
        token_type: token_type
      }) do
    [paging_options: %{@default_paging_options | key: {token_contract_address_hash, token_id, token_type}}]
  end

  def paging_options(%{token_contract_address_hash: token_contract_address_hash, token_type: token_type}) do
    [paging_options: %{@default_paging_options | key: {token_contract_address_hash, token_type}}]
  end

  # Clause for `Explorer.Chain.Stability.Validator`,
  #  returned by `BlockScoutWeb.API.V2.ValidatorController.stability_validators_list/2` (`/api/v2/validators/stability`)
  def paging_options(%{
        "state" => state,
        "address_hash" => address_hash_string,
        "blocks_validated" => blocks_validated_string
      }) do
    [
      paging_options: %{
        @default_paging_options
        | key: %{
            address_hash: parse_address_hash(address_hash_string),
            blocks_validated: parse_integer(blocks_validated_string),
            state: if(state in PagingHelper.allowed_stability_validators_states(), do: state)
          }
      }
    ]
  end

  # Clause for InternalTransaction by block:
  #   returned by `BlockScoutWeb.API.V2.BlockController.internal_transactions/2` (`/api/v2/blocks/:block_hash_or_number/internal-transactions`)
  def paging_options(%{"block_index" => index_string}) when is_binary(index_string) do
    case Integer.parse(index_string) do
      {index, ""} ->
        [paging_options: %{@default_paging_options | key: %{block_index: index}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"block_index" => index}) when is_integer(index) do
    [paging_options: %{@default_paging_options | key: %{block_index: index}}]
  end

  # Clause for `Explorer.Chain.Blackfort.Validator`,
  #  returned by `BlockScoutWeb.API.V2.ValidatorController.blackfort_validators_list/2` (`/api/v2/validators/blackfort`)
  def paging_options(%{
        "address_hash" => address_hash_string
      }) do
    [
      paging_options: %{
        @default_paging_options
        | key: %{
            address_hash: parse_address_hash(address_hash_string)
          }
      }
    ]
  end

  def paging_options(_params), do: [paging_options: @default_paging_options]

  def put_key_value_to_paging_options([paging_options: paging_options], key, value) do
    [paging_options: Map.put(paging_options, key, value)]
  end

  def fetch_page_number(%{"page_number" => page_number_string}) do
    case Integer.parse(page_number_string) do
      {number, ""} ->
        number

      _ ->
        1
    end
  end

  def fetch_page_number(%{"items_count" => items_count_str}) do
    {items_count, _} = Integer.parse(items_count_str)
    div(items_count, @page_size) + 1
  end

  def fetch_page_number(_), do: 1

  def update_page_parameters(new_page_number, new_page_size, %PagingOptions{} = options) do
    %PagingOptions{options | page_number: new_page_number, page_size: new_page_size}
  end

  @spec param_to_block_number(binary()) :: {:ok, integer()} | {:error, :invalid}
  def param_to_block_number(formatted_number) when is_binary(formatted_number) do
    case Integer.parse(formatted_number) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid}
    end
  end

  @doc """
  Converts a timestamp string to a `DateTime.t()` struct for block timestamp
  queries.

  ## Parameters
  - `timestamp_string`: A string containing a Unix timestamp in seconds

  ## Returns
  - `{:ok, DateTime.t()}` if the timestamp is valid and can be converted
  - `{:error, :invalid_timestamp}` if the timestamp is invalid or out of range
  """
  @spec param_to_block_timestamp(String.t()) :: {:ok, DateTime.t()} | {:error, :invalid_timestamp}
  def param_to_block_timestamp(timestamp_string) when is_binary(timestamp_string) do
    with {timestamp_int, ""} <- Integer.parse(timestamp_string),
         {:ok, timestamp} <- DateTime.from_unix(timestamp_int, :second) do
      {:ok, timestamp}
    else
      _ -> {:error, :invalid_timestamp}
    end
  end

  def param_to_block_closest(closest) when is_binary(closest) do
    case closest do
      "before" -> {:ok, :before}
      "after" -> {:ok, :after}
      _ -> {:error, :invalid_closest}
    end
  end

  def split_list_by_page(list_plus_one), do: Enum.split(list_plus_one, @page_size)

  defp decimal_parse(input_string) do
    case Decimal.parse(input_string) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp address_from_param(param) do
    case string_to_address_hash(param) do
      {:ok, hash} ->
        {:ok, %Address{hash: hash}}

      :error ->
        {:error, :not_found}
    end
  end

  defp search_ens_domain(search_query) do
    case Search.search_ens_name_in_bens(search_query) do
      nil ->
        {:error, :not_found}

      {result, _address_hash} ->
        {:ok, result}
    end
  end

  defp parse_address_hash(address_hash_string) do
    case Hash.Address.cast(address_hash_string) do
      {:ok, address_hash} -> address_hash
      _ -> nil
    end
  end

  defp paging_params(%Address{
         hash: hash,
         fetched_coin_balance: fetched_coin_balance,
         transactions_count: transactions_count
       }) do
    %{
      hash: hash,
      fetched_coin_balance: fetched_coin_balance && Wei.to(fetched_coin_balance, :wei),
      transactions_count: transactions_count
    }
  end

  defp paging_params(%Token{
         contract_address_hash: contract_address_hash,
         circulating_market_cap: circulating_market_cap,
         holder_count: holder_count,
         name: token_name,
         fiat_value: fiat_value
       }) do
    %{
      "market_cap" => circulating_market_cap,
      "holders_count" => holder_count,
      # todo: It should be removed in favour `holders_count` property with the next release after 8.0.0
      "holder_count" => holder_count,
      "contract_address_hash" => contract_address_hash,
      "name" => token_name,
      "is_name_null" => is_nil(token_name),
      "fiat_value" => fiat_value
    }
  end

  defp paging_params({%Token{} = token, _}) do
    paging_params(token)
  end

  defp paging_params(%OptimismFrameSequence{id: id}) do
    %{"id" => id}
  end

  defp paging_params(%TagAddress{id: id}) do
    %{"id" => id}
  end

  defp paging_params(%TagTransaction{id: id}) do
    %{"id" => id}
  end

  defp paging_params(%WatchlistAddress{id: id}) do
    %{"id" => id}
  end

  defp paging_params([%Token{} = token, _]) do
    paging_params(token)
  end

  defp paging_params({%Reward{block: %{number: number}}, _}) do
    %{"block_number" => number, "index" => 0}
  end

  defp paging_params(%Block{number: number}) do
    %{block_number: number}
  end

  defp paging_params(%InternalTransaction{index: index, transaction_hash: transaction_hash}) do
    {:ok, %Transaction{block_number: block_number, index: transaction_index}} = hash_to_transaction(transaction_hash)
    %{block_number: block_number, transaction_index: transaction_index, index: index}
  end

  defp paging_params(%Log{index: index, block_number: block_number}) do
    %{block_number: block_number, index: index}
  end

  defp paging_params(%Transaction{block_number: nil, inserted_at: inserted_at, hash: hash}) do
    %{"inserted_at" => DateTime.to_iso8601(inserted_at), "hash" => hash}
  end

  defp paging_params(%Transaction{block_number: block_number, index: index}) do
    %{"block_number" => block_number, "index" => index}
  end

  defp paging_params(%TokenTransfer{block_number: block_number, log_index: index}) do
    %{block_number: block_number, index: index}
  end

  defp paging_params(%Address.Token{name: name, type: type, inserted_at: inserted_at}) do
    inserted_at_datetime = DateTime.to_iso8601(inserted_at)

    %{"token_name" => name, "token_type" => type, "token_inserted_at" => inserted_at_datetime}
  end

  defp paging_params(%CurrentTokenBalance{address_hash: address_hash, value: value}) do
    %{"address_hash" => to_string(address_hash), "value" => Decimal.to_integer(value)}
  end

  defp paging_params(%CoinBalance{block_number: block_number}) do
    %{block_number: block_number}
  end

  defp paging_params(%SmartContract{address: %NotLoaded{}} = smart_contract) do
    %{"smart_contract_id" => smart_contract.id}
  end

  defp paging_params(%OptimismDeposit{l1_block_number: l1_block_number, l2_transaction_hash: l2_transaction_hash}) do
    %{"l1_block_number" => l1_block_number, "transaction_hash" => l2_transaction_hash}
  end

  defp paging_params(%OptimismOutputRoot{l2_output_index: index}) do
    %{"index" => index}
  end

  defp paging_params(%OptimismInteropMessage{timestamp: timestamp, init_transaction_hash: init_transaction_hash}) do
    %{"timestamp" => DateTime.to_unix(timestamp), "init_transaction_hash" => init_transaction_hash}
  end

  defp paging_params(%SmartContract{} = smart_contract) do
    %{
      "smart_contract_id" => smart_contract.id,
      "transactions_count" => smart_contract.address.transactions_count,
      # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
      "transaction_count" => smart_contract.address.transactions_count,
      "coin_balance" =>
        smart_contract.address.fetched_coin_balance && Wei.to(smart_contract.address.fetched_coin_balance, :wei)
    }
  end

  defp paging_params(%ScrollBridge{index: id}) do
    %{"id" => id}
  end

  defp paging_params(%{index: index}) do
    %{"index" => index}
  end

  defp paging_params(%Withdrawal{index: index}) do
    %{index: index}
  end

  defp paging_params(%{msg_nonce: nonce}) do
    %{"nonce" => nonce}
  end

  defp paging_params(%{l2_block_number: block_number}) do
    %{"block_number" => block_number}
  end

  # clause for zkEVM & Scroll batches pagination
  defp paging_params(%{number: number}) do
    %{"number" => number}
  end

  defp paging_params(%Instance{token_id: token_id}) do
    %{"unique_token" => Decimal.to_integer(token_id)}
  end

  defp paging_params(%StateChange{}) do
    %{"state_changes" => nil}
  end

  # clause for Polygon Edge Deposits and Withdrawals
  defp paging_params(%{msg_id: msg_id}) do
    %{"id" => msg_id}
  end

  # clause for Shibarium Deposits
  defp paging_params(%{l1_block_number: block_number}) do
    %{"block_number" => block_number}
  end

  # clause for Shibarium Withdrawals
  defp paging_params(%{l2_block_number: block_number}) do
    %{"block_number" => block_number}
  end

  @spec paging_params_with_fiat_value(CurrentTokenBalance.t()) :: %{
          required(atom()) => Decimal.t() | non_neg_integer() | nil
        }
  def paging_params_with_fiat_value(%CurrentTokenBalance{id: id, value: value} = ctb) do
    %{fiat_value: ctb.fiat_value, value: value, id: id}
  end

  defp block_or_transaction_or_operation_or_blob_from_param(param) do
    with {:ok, hash} <- string_to_full_hash(param),
         {:error, :not_found} <- hash_to_transaction(hash),
         {:error, :not_found} <- hash_to_block(hash),
         {:error, :not_found} <- hash_to_user_operation(hash),
         {:error, :not_found} <- hash_to_blob(hash) do
      {:error, :not_found}
    else
      :error -> {:error, :not_found}
      res -> res
    end
  end

  defp hash_to_user_operation(hash) do
    if UserOperation.enabled?() do
      UserOperation.hash_to_user_operation(hash)
    else
      {:error, :not_found}
    end
  end

  defp hash_to_blob(hash) do
    if Application.get_env(:explorer, :chain_type) == :ethereum do
      BeaconReader.blob(hash, false)
    else
      {:error, :not_found}
    end
  end

  def unique_tokens_paging_options(%{"unique_token" => token_id}),
    do: [paging_options: %{default_paging_options() | key: {token_id}}]

  def unique_tokens_paging_options(_params), do: [paging_options: default_paging_options()]

  def unique_tokens_next_page([], _list, _params), do: nil

  def unique_tokens_next_page(_, list, params) do
    Map.merge(params, paging_params(List.last(list)))
  end

  def token_transfers_next_page_params([], _list, _params), do: nil

  def token_transfers_next_page_params(next_page, list, params) do
    next_token_transfer = List.first(next_page)
    current_token_transfer = List.last(list)

    if next_token_transfer.log_index == current_token_transfer.log_index and
         next_token_transfer.block_hash == current_token_transfer.block_hash and
         next_token_transfer.transaction_hash == current_token_transfer.transaction_hash do
      new_params =
        list
        |> last_token_transfer_before_current(current_token_transfer)
        |> (&if(is_nil(&1), do: %{}, else: paging_params(&1))).()

      params
      |> Map.merge(new_params)
      |> Map.merge(%{
        batch_log_index: current_token_transfer.log_index,
        batch_block_hash: current_token_transfer.block_hash,
        batch_transaction_hash: current_token_transfer.transaction_hash,
        index_in_batch: current_token_transfer.index_in_batch
      })
    else
      Map.merge(params, paging_params(List.last(list)))
    end
  end

  defp last_token_transfer_before_current(list, current_token_transfer) do
    Enum.reduce_while(list, nil, fn tt, acc ->
      if tt.log_index == current_token_transfer.log_index and tt.block_hash == current_token_transfer.block_hash and
           tt.transaction_hash == current_token_transfer.transaction_hash do
        {:halt, acc}
      else
        {:cont, tt}
      end
    end)
  end

  def parse_block_hash_or_number_param("0x" <> _ = param) do
    case string_to_full_hash(param) do
      {:ok, hash} ->
        {:ok, :hash, hash}

      :error ->
        {:error, {:invalid, :hash}}
    end
  end

  def parse_block_hash_or_number_param(number_string)
      when is_binary(number_string) do
    case param_to_block_number(number_string) do
      {:ok, number} ->
        {:ok, :number, number}

      {:error, :invalid} ->
        {:error, {:invalid, :number}}
    end
  end

  @doc """
  Fetches the scam token toggle from conn.cookies["show_scam_tokens"]. And put it to the params keyword.

  ## Parameters

    - params: Initial params to append scam token toggle info.
    - conn: The connection.

  ## Returns

  Provided params keyword with the new field `show_scam_tokens?`.
  """
  @spec fetch_scam_token_toggle(Keyword.t(), Plug.Conn.t()) :: Keyword.t()
  def fetch_scam_token_toggle(params, conn),
    do: Keyword.put(params, :show_scam_tokens?, conn.cookies["show_scam_tokens"] |> parse_boolean())
end
