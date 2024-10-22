defmodule BlockScoutWeb.Account.API.V2.TagsView do
  def render("address_tags.json", %{tags_map: tags_map}) do
    tags_map
  end

  def render("transaction_tags.json", %{
        tags_map: %{
          personal_tags: personal_tags,
          watchlist_names: watchlist_names,
          personal_transaction_tag: personal_transaction_tag,
          common_tags: common_tags
        }
      }) do
    %{
      personal_transaction_tag: prepare_transaction_tag(personal_transaction_tag),
      # todo: keep next line for compatibility with frontend and remove when new frontend is bound to `personal_transaction_tag` property
      personal_tx_tag: prepare_transaction_tag(personal_transaction_tag),
      personal_tags: personal_tags,
      watchlist_names: watchlist_names,
      common_tags: common_tags
    }
  end

  def prepare_transaction_tag(nil), do: nil

  def prepare_transaction_tag(transaction_tag) do
    %{"label" => transaction_tag.name}
  end
end
