defmodule AddTagAddress do
  @moduledoc """
  Create tag address, associated with Address and Identity
  """

  alias Explorer.Accounts.TagAddress
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address

  def call(identity_id, %{"address_hash" => address_hash_string} = params) do
    case format_address(address_hash_string) do
      {:ok, address_hash} ->
        try_create_tag_address(identity_id, address_hash, params)

      :error ->
        {:error, "Wrong address, "}
    end
  end

  defp try_create_tag_address(identity_id, address_hash, params) do
    case find_tag_address(identity_id, address_hash) do
      %TagAddress{} ->
        {:error, "Address tag already exists!"}

      nil ->
        with {:ok, %Address{} = address} <- find_or_create_address(address_hash) do
          address
          |> build_tag_address(identity_id, params)
          |> Repo.insert()
        end
    end
  end

  defp format_address(address_hash_string) do
    Chain.string_to_address_hash(address_hash_string)
  end

  defp find_tag_address(identity_id, address_hash) do
    Repo.get_by(TagAddress,
      address_hash: address_hash,
      identity_id: identity_id
    )
  end

  defp find_or_create_address(address_hash) do
    with {:error, :address_not_found} <- find_address(address_hash),
         do: create_address(address_hash)
  end

  defp create_address(address_hash) do
    with {:error, _} <- Repo.insert(%Address{hash: address_hash}),
         do: {:error, :wrong_address}
  end

  defp find_address(address_hash) do
    case Repo.get(Address, address_hash) do
      nil -> {:error, :address_not_found}
      %Address{} = address -> {:ok, address}
    end
  end

  defp build_tag_address(address, identity_id, %{"name" => name}) do
    TagAddress.changeset(
      %TagAddress{
        identity_id: identity_id,
        address_hash: address.hash
      },
      %{name: name}
    )
  end
end
