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

  # Functions

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

  ## Private Functions

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
end
