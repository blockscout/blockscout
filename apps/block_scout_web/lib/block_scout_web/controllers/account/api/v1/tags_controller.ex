defmodule BlockScoutWeb.Account.Api.V1.TagsController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.Models.{GetAddressTags, GetTransactionTags, UserFromAuth}
  alias Explorer.Account.Identity
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash.{Address, Full}

  action_fallback(BlockScoutWeb.Account.Api.V1.FallbackController)

  def tags_address(conn, %{"address_hash" => address_hash}) do
    personal_tags =
      if is_nil(current_user(conn)) do
        %{personal_tags: [], watchlist_names: []}
      else
        uid = current_user(conn).id

        with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
             {:watchlist, %{watchlists: [watchlist | _]}} <-
               {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
             {:address_hash, {:ok, address_hash}} <- {:address_hash, Address.cast(address_hash)} do
          GetAddressTags.get_address_tags(address_hash, %{id: identity.id, watchlist_id: watchlist.id})
        else
          _ ->
            %{personal_tags: [], watchlist_names: []}
        end
      end

    public_tags =
      case Address.cast(address_hash) do
        {:ok, address_hash} ->
          GetAddressTags.get_public_tags(address_hash)

        _ ->
          %{common_tags: []}
      end

    conn
    |> put_status(200)
    |> render(:address_tags, %{tags_map: Map.merge(personal_tags, public_tags)})
  end

  def tags_transaction(conn, %{"transaction_hash" => transaction_hash}) do
    transaction =
      with {:ok, transaction_hash} <- Full.cast(transaction_hash),
           {:ok, transaction} <- Chain.hash_to_transaction(transaction_hash) do
        transaction
      else
        _ ->
          nil
      end

    personal_tags =
      if is_nil(current_user(conn)) do
        %{personal_tags: [], watchlist_names: [], personal_tx_tag: nil}
      else
        uid = current_user(conn).id

        with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
             {:watchlist, %{watchlists: [watchlist | _]}} <-
               {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
             false <- is_nil(transaction) do
          GetTransactionTags.get_transaction_with_addresses_tags(transaction, %{
            id: identity.id,
            watchlist_id: watchlist.id
          })
        else
          _ ->
            %{personal_tags: [], watchlist_names: [], personal_tx_tag: nil}
        end
      end

    public_tags_from =
      if is_nil(transaction), do: [], else: GetAddressTags.get_public_tags(transaction.from_address_hash).common_tags

    public_tags_to =
      if is_nil(transaction), do: [], else: GetAddressTags.get_public_tags(transaction.to_address_hash).common_tags

    public_tags = %{common_tags: public_tags_from ++ public_tags_to}

    conn
    |> put_status(200)
    |> render(:transaction_tags, %{tags_map: Map.merge(personal_tags, public_tags)})
  end
end
