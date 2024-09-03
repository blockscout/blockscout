defmodule BlockScoutWeb.Models.GetTransactionTags do
  @moduledoc """
  Get various types of tags associated with the transaction
  """

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2, get_tags_on_address: 1]

  alias Explorer.Account.TagTransaction
  alias Explorer.Chain.Transaction

  def get_transaction_with_addresses_tags(
        %Transaction{} = transaction,
        %{id: identity_id, watchlist_id: watchlist_id}
      ) do
    transaction_tag = get_transaction_tags(transaction.hash, %{id: identity_id})
    addresses_tags = get_addresses_tags_for_transaction(transaction, %{id: identity_id, watchlist_id: watchlist_id})
    Map.put(addresses_tags, :personal_transaction_tag, transaction_tag)
  end

  def get_transaction_with_addresses_tags(%Transaction{} = transaction, _),
    do: %{
      common_tags: get_tags_on_address(transaction.to_address_hash),
      personal_tags: [],
      watchlist_names: [],
      personal_transaction_tag: nil
    }

  def get_transaction_tags(transaction_hash, %{id: identity_id}) do
    case TagTransaction.get_tag_transaction_by_transaction_hash_and_identity_id(transaction_hash, identity_id) do
      [tag | _] -> tag
      _ -> nil
    end
  end

  def get_transaction_tags(_, _), do: nil

  def get_addresses_tags_for_transaction(
        %Transaction{} = transaction,
        %{id: identity_id, watchlist_id: watchlist_id}
      ) do
    from_tags = get_address_tags(transaction.from_address_hash, %{id: identity_id, watchlist_id: watchlist_id})
    to_tags = get_address_tags(transaction.to_address_hash, %{id: identity_id, watchlist_id: watchlist_id})

    %{
      common_tags: get_tags_on_address(transaction.to_address_hash),
      personal_tags: Enum.dedup(from_tags.personal_tags ++ to_tags.personal_tags),
      watchlist_names: Enum.dedup(from_tags.watchlist_names ++ to_tags.watchlist_names)
    }
  end
end
