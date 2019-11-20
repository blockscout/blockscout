defmodule BlockScoutWeb.Chain do
  @moduledoc """
  Converts the `param` to the corresponding resource that uses that format of param.
  """

  import Explorer.Chain,
    only: [
      find_or_insert_address_from_hash: 1,
      hash_to_block: 1,
      hash_to_transaction: 1,
      number_to_block: 1,
      string_to_address_hash: 1,
      string_to_block_hash: 1,
      string_to_transaction_hash: 1,
      token_contract_address_from_token_name: 1
    ]

  alias Explorer.Chain.Block.Reward

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CurrentTokenBalance,
    Block,
    InternalTransaction,
    Log,
    Token,
    TokenTransfer,
    Transaction,
    StakingPool,
    Wei
  }

  alias Explorer.PagingOptions

  defimpl Poison.Encoder, for: Decimal do
    def encode(value, _opts) do
      # silence the xref warning
      decimal = Decimal

      [?\", decimal.to_string(value), ?\"]
    end
  end

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}
  @address_hash_len 40
  @tx_block_hash_len 64

  def default_paging_options do
    @default_paging_options
  end

  def current_filter(%{paging_options: paging_options} = params) do
    params
    |> Map.get("filter")
    |> case do
      "to" -> [direction: :to, paging_options: paging_options]
      "from" -> [direction: :from, paging_options: paging_options]
      _ -> [paging_options: paging_options]
    end
  end

  def current_filter(params) do
    params
    |> Map.get("filter")
    |> case do
      "to" -> [direction: :to]
      "from" -> [direction: :from]
      _ -> []
    end
  end

  @spec from_param(String.t()) :: {:ok, Address.t() | Block.t() | Transaction.t()} | {:error, :not_found}
  def from_param(param)

  def from_param("0x" <> number_string = param) when byte_size(number_string) == @address_hash_len,
    do: address_from_param(param)

  def from_param("0x" <> number_string = param) when byte_size(number_string) == @tx_block_hash_len,
    do: block_or_transaction_from_param(param)

  def from_param(param) when byte_size(param) == @address_hash_len,
    do: address_from_param("0x" <> param)

  def from_param(param) when byte_size(param) == @tx_block_hash_len,
    do: block_or_transaction_from_param("0x" <> param)

  def from_param(string) when is_binary(string) do
    case param_to_block_number(string) do
      {:ok, number} -> number_to_block(number)
      _ -> token_address_from_name(string)
    end
  end

  def next_page_params([], _list, _params), do: nil

  def next_page_params(_, list, params) do
    next_page_params = Map.merge(params, paging_params(List.last(list)))
    current_items_count_str = Map.get(next_page_params, "items_count")

    items_count =
      if current_items_count_str do
        {current_items_count, _} = Integer.parse(current_items_count_str)
        current_items_count + Enum.count(list)
      else
        Enum.count(list)
      end

    Map.put(next_page_params, "items_count", items_count)
  end

  def paging_options(%{"hash" => hash, "fetched_coin_balance" => fetched_coin_balance}) do
    with {coin_balance, ""} <- Integer.parse(fetched_coin_balance),
         {:ok, address_hash} <- string_to_address_hash(hash) do
      [paging_options: %{@default_paging_options | key: {%Wei{value: Decimal.new(coin_balance)}, address_hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"holder_count" => holder_count, "name" => token_name}) do
    case Integer.parse(holder_count) do
      {holder_count, ""} ->
        [paging_options: %{@default_paging_options | key: {holder_count, token_name}}]

      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{
        "block_number" => block_number_string,
        "transaction_index" => transaction_index_string,
        "index" => index_string
      }) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {transaction_index, ""} <- Integer.parse(transaction_index_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, transaction_index, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"block_number" => block_number_string, "index" => index_string}) do
    with {block_number, ""} <- Integer.parse(block_number_string),
         {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {block_number, index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"block_number" => block_number_string}) do
    case Integer.parse(block_number_string) do
      {block_number, ""} ->
        [paging_options: %{@default_paging_options | key: {block_number}}]

      _ ->
        [paging_options: @default_paging_options]
    end
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

  def paging_options(%{"inserted_at" => inserted_at_string, "hash" => hash_string}) do
    with {:ok, inserted_at, _} <- DateTime.from_iso8601(inserted_at_string),
         {:ok, hash} <- string_to_transaction_hash(hash_string) do
      [paging_options: %{@default_paging_options | key: {inserted_at, hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"token_name" => name, "token_type" => type, "token_inserted_at" => inserted_at}),
    do: [paging_options: %{@default_paging_options | key: {name, type, inserted_at}}]

  def paging_options(%{"value" => value, "address_hash" => address_hash}) do
    [paging_options: %{@default_paging_options | key: {value, address_hash}}]
  end

  def paging_options(_params), do: [paging_options: @default_paging_options]

  def param_to_block_number(formatted_number) when is_binary(formatted_number) do
    case Integer.parse(formatted_number) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid}
    end
  end

  def split_list_by_page(list_plus_one), do: Enum.split(list_plus_one, @page_size)

  defp address_from_param(param) do
    case string_to_address_hash(param) do
      {:ok, hash} ->
        find_or_insert_address_from_hash(hash)

      :error ->
        {:error, :not_found}
    end
  end

  defp token_address_from_name(name) do
    case token_contract_address_from_token_name(name) do
      {:ok, hash} -> find_or_insert_address_from_hash(hash)
      _ -> {:error, :not_found}
    end
  end

  defp paging_params({%Address{hash: hash, fetched_coin_balance: fetched_coin_balance}, _}) do
    %{"hash" => hash, "fetched_coin_balance" => Decimal.to_string(fetched_coin_balance.value)}
  end

  defp paging_params(%Token{holder_count: holder_count, name: token_name}) do
    %{"holder_count" => holder_count, "name" => token_name}
  end

  defp paging_params([%Token{holder_count: holder_count, name: token_name}, _]) do
    %{"holder_count" => holder_count, "name" => token_name}
  end

  defp paging_params({%Reward{block: %{number: number}}, _}) do
    %{"block_number" => number, "index" => 0}
  end

  defp paging_params(%Block{number: number}) do
    %{"block_number" => number}
  end

  defp paging_params(%InternalTransaction{index: index, transaction_hash: transaction_hash}) do
    {:ok, %Transaction{block_number: block_number, index: transaction_index}} = hash_to_transaction(transaction_hash)
    %{"block_number" => block_number, "transaction_index" => transaction_index, "index" => index}
  end

  defp paging_params(%Log{index: index} = log) do
    if Ecto.assoc_loaded?(log.transaction) do
      %{"block_number" => log.transaction.block_number, "transaction_index" => log.transaction.index, "index" => index}
    else
      %{"index" => index}
    end
  end

  defp paging_params(%Transaction{block_number: nil, inserted_at: inserted_at, hash: hash}) do
    %{"inserted_at" => DateTime.to_iso8601(inserted_at), "hash" => hash}
  end

  defp paging_params(%Transaction{block_number: block_number, index: index}) do
    %{"block_number" => block_number, "index" => index}
  end

  defp paging_params(%TokenTransfer{block_number: block_number, log_index: index}) do
    %{"block_number" => block_number, "index" => index}
  end

  defp paging_params(%Address.Token{name: name, type: type, inserted_at: inserted_at}) do
    inserted_at_datetime = DateTime.to_iso8601(inserted_at)

    %{"token_name" => name, "token_type" => type, "token_inserted_at" => inserted_at_datetime}
  end

  defp paging_params(%CurrentTokenBalance{address_hash: address_hash, value: value}) do
    %{"address_hash" => to_string(address_hash), "value" => Decimal.to_integer(value)}
  end

  defp paging_params(%CoinBalance{block_number: block_number}) do
    %{"block_number" => block_number}
  end

  defp paging_params(%StakingPool{staking_address_hash: address_hash, stakes_ratio: value}) do
    %{"address_hash" => address_hash, "value" => Decimal.to_string(value)}
  end

  defp block_or_transaction_from_param(param) do
    with {:error, :not_found} <- transaction_from_param(param) do
      hash_string_to_block(param)
    end
  end

  defp transaction_from_param(param) do
    case string_to_transaction_hash(param) do
      {:ok, hash} ->
        hash_to_transaction(hash)

      :error ->
        {:error, :not_found}
    end
  end

  defp hash_string_to_block(hash_string) do
    case string_to_block_hash(hash_string) do
      {:ok, hash} ->
        hash_to_block(hash)

      :error ->
        {:error, :not_found}
    end
  end
end
