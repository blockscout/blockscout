defmodule ExplorerWeb.Chain do
  @moduledoc """
  Converts the `param` to the corresponding resource that uses that format of param.
  """

  import Explorer.Chain,
    only: [
      hash_to_address: 1,
      hash_to_transaction: 1,
      number_to_block: 1,
      string_to_address_hash: 1,
      string_to_transaction_hash: 1
    ]

  alias Explorer.Chain.{Address, Block, Transaction}
  alias Explorer.PagingOptions

  @page_size 50
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

  @spec from_param(String.t()) :: {:ok, Address.t() | Block.t() | Transaction.t()} | {:error, :not_found}
  def from_param(param)

  def from_param("0x" <> number_string = param) do
    case String.length(number_string) do
      40 -> address_from_param(param)
      64 -> transaction_from_param(param)
      _ -> {:error, :not_found}
    end
  end

  def from_param(formatted_number) when is_binary(formatted_number) do
    case param_to_block_number(formatted_number) do
      {:ok, number} -> number_to_block(number)
      {:error, :invalid} -> {:error, :not_found}
    end
  end

  def param_to_block_number(formatted_number) when is_binary(formatted_number) do
    case Integer.parse(formatted_number) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid}
    end
  end

  defp address_from_param(param) do
    with {:ok, hash} <- string_to_address_hash(param) do
      hash_to_address(hash)
    else
      :error -> {:error, :not_found}
    end
  end

  defp transaction_from_param(param) do
    with {:ok, hash} <- string_to_transaction_hash(param) do
      hash_to_transaction(hash)
    else
      :error -> {:error, :not_found}
    end
  end

  def paging_options(
        %{
          "block_number" => block_number_string,
          "transaction_index" => transaction_index_string,
          "index" => index_string
        }
      ) do
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

  def paging_options(_params), do: [paging_options: @default_paging_options]
end
