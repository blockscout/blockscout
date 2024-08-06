defmodule Explorer.Account.Notifier.ForbiddenAddress do
  @moduledoc """
    Check if address is forbidden to notify
  """

  import Explorer.Chain.SmartContract,
    only: [
      burn_address_hash_string: 0,
      dead_address_hash_string: 0
    ]

  alias Explorer.Chain.Address

  @blacklist [
    burn_address_hash_string(),
    dead_address_hash_string()
  ]

  alias Explorer.AccessHelper

  import Explorer.Chain, only: [string_to_address_hash: 1, hash_to_address: 1]

  def check(address_string) when is_bitstring(address_string) do
    case format_address(address_string) do
      {:error, message} ->
        {:error, message}

      address_hash ->
        check(address_hash)
    end
  end

  def check(%Explorer.Chain.Hash{} = address_hash) do
    cond do
      address_hash in blacklist() ->
        {:error, "This address is blacklisted"}

      contract?(address_hash) ->
        {:error, "This address isn't EOA"}

      match?({:restricted_access, true}, AccessHelper.restricted_access?(to_string(address_hash), %{})) ->
        {:error, "This address has restricted access"}

      address_hash ->
        {:ok, address_hash}
    end
  end

  defp contract?(%Explorer.Chain.Hash{} = address_hash) do
    case hash_to_address(address_hash) do
      {:error, :not_found} -> false
      {:ok, address} -> Address.smart_contract?(address)
    end
  end

  defp format_address(address_hash_string) do
    case string_to_address_hash(address_hash_string) do
      {:ok, address_hash} ->
        address_hash

      :error ->
        {:error, "Address is invalid"}
    end
  end

  defp blacklist do
    Enum.map(
      @blacklist,
      &format_address(&1)
    )
  end
end
