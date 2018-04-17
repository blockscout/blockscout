defmodule ExplorerWeb.Chain do
  @moduledoc """
  Converts the `param` to the corresponding resource that uses that format of param.
  """

  import Explorer.Chain, only: [hash_to_address: 1, hash_to_transaction: 1, number_to_block: 1]

  @spec from_param(String.t()) ::
          {:ok, Address.t() | Transaction.t() | Block.t()} | {:error, :not_found}
  def from_param(param)

  def from_param(hash) when byte_size(hash) > 42 do
    hash_to_transaction(hash)
  end

  def from_param(hash) when byte_size(hash) == 42 do
    hash_to_address(hash)
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
end
