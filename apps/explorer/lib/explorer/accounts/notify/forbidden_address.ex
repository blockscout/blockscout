defmodule Explorer.Accounts.Notify.ForbiddenAddress do
  @moduledoc """
    Check if address is forbidden to notify
  """

  @blacklist [
    "0x0000000000000000000000000000000000000000",
    "0x000000000000000000000000000000000000dEaD"
  ]

  alias Explorer.Chain.Token
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]
  import Explorer.Chain, only: [string_to_address_hash: 1]

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
        {:error, "This address is blacklisted."}

      is_contract(address_hash) ->
        {:error, "This address isn't personal."}

      address_hash ->
        {:ok, address_hash}
    end
  end

  defp is_contract(%Explorer.Chain.Hash{} = address_hash) do
    query =
      from(
        token in Token,
        where: token.contract_address_hash == ^address_hash
      )

    contract_addresses = Repo.all(query)
    List.first(contract_addresses)
  end

  defp format_address(address_hash_string) do
    case string_to_address_hash(address_hash_string) do
      {:ok, address_hash} ->
        address_hash

      :error ->
        {:error, "Address "}
    end
  end

  defp blacklist do
    Enum.map(
      @blacklist,
      &format_address(&1)
    )
  end
end
