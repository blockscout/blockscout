defmodule AddTagTransaction do
  @moduledoc """
  Create tag transaction, 
  associated with Transaction and Identity
  """

  alias Explorer.Accounts.TagTransaction
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Transaction

  def call(identity_id, %{"tx_hash" => tx_hash_string} = params) do
    case format_tx(tx_hash_string) do
      {:ok, tx_hash} ->
        try_create_tag_tx(identity_id, tx_hash, params)

      :error ->
        {:error, "Wrong address, "}
    end
  end

  defp try_create_tag_tx(identity_id, tx_hash, params) do
    case find_tag_tx(identity_id, tx_hash) do
      %TagTransaction{} ->
        {:error, "Transaction tag already exists!"}

      nil ->
        with {:ok, %Transaction{} = address} <- find_or_create_tx(tx_hash) do
          address
          |> build_tag_tx(identity_id, params)
          |> Repo.insert()
        end
    end
  end

  defp format_tx(tx_hash_string) do
    Chain.string_to_transaction_hash(tx_hash_string)
  end

  defp find_tag_tx(identity_id, tx_hash) do
    Repo.get_by(TagTransaction,
      tx_hash: tx_hash,
      identity_id: identity_id
    )
  end

  defp find_or_create_tx(tx_hash) do
    with {:error, :tx_not_found} <- find_tx(tx_hash),
         do: create_tx(tx_hash)
  end

  defp create_tx(tx_hash) do
    with {:error, _} <- Repo.insert(%Transaction{hash: tx_hash}),
         do: {:error, :wrong_tx}
  end

  defp find_tx(tx_hash) do
    case Repo.get(Transaction, tx_hash) do
      nil -> {:error, :tx_not_found}
      %Transaction{} = address -> {:ok, address}
    end
  end

  defp build_tag_tx(address, identity_id, %{"name" => name}) do
    TagTransaction.changeset(
      %TagTransaction{
        identity_id: identity_id,
        tx_hash: address.hash
      },
      %{name: name}
    )
  end
end
