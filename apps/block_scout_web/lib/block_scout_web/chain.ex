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
      string_to_transaction_hash: 1
    ]

  alias Explorer.Chain.Block.Reward

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CurrentTokenBalance,
    Block,
    InternalTransaction,
    Log,
    TokenTransfer,
    Transaction
  }

  alias Explorer.PagingOptions

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

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

  def from_param("0x" <> number_string = param) do
    case String.length(number_string) do
      40 -> address_from_param(param)
      64 -> block_or_transaction_from_param(param)
      _ -> {:error, :not_found}
    end
  end

  def from_param(formatted_number) when is_binary(formatted_number) do
    case param_to_block_number(formatted_number) do
      {:ok, number} -> number_to_block(number)
      {:error, :invalid} -> {:error, :not_found}
    end
  end

  def next_page_params([], _list, _params), do: nil

  def next_page_params(_, list, params) do
    Map.merge(params, paging_params(List.last(list)))
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
    with {block_number, ""} <- Integer.parse(block_number_string) do
      [paging_options: %{@default_paging_options | key: {block_number}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def paging_options(%{"index" => index_string}) do
    with {index, ""} <- Integer.parse(index_string) do
      [paging_options: %{@default_paging_options | key: {index}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
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
    with {:ok, hash} <- string_to_address_hash(param) do
      find_or_insert_address_from_hash(hash)
    else
      :error -> {:error, :not_found}
    end
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

  defp paging_params(%Log{index: index}) do
    %{"index" => index}
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

  defp block_or_transaction_from_param(param) do
    with {:error, :not_found} <- transaction_from_param(param) do
      hash_string_to_block(param)
    end
  end

  defp transaction_from_param(param) do
    with {:ok, hash} <- string_to_transaction_hash(param) do
      hash_to_transaction(hash)
    else
      :error -> {:error, :not_found}
    end
  end

  defp hash_string_to_block(hash_string) do
    with {:ok, hash} <- string_to_block_hash(hash_string) do
      hash_to_block(hash)
    else
      :error -> {:error, :not_found}
    end
  end
end
