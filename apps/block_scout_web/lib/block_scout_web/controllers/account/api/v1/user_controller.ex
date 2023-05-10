defmodule BlockScoutWeb.Account.Api.V1.UserController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import Ecto.Query, only: [from: 2]

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.Api.Key, as: ApiKey
  alias Explorer.Account.CustomABI
  alias Explorer.Account.{Identity, PublicTagsRequest, TagAddress, TagTransaction, WatchlistAddress}
  alias Explorer.ExchangeRates.Token
  alias Explorer.{Market, Repo}
  alias Plug.CSRFProtection

  action_fallback(BlockScoutWeb.Account.Api.V1.FallbackController)

  @ok_message "OK"

  def info(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)} do
      conn
      |> put_status(200)
      |> render(:user_info, %{identity: identity})
    end
  end

  def watchlist(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <-
           {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
         watchlist_with_addresses <- preload_watchlist_addresses(watchlist) do
      conn
      |> put_status(200)
      |> render(:watchlist_addresses, %{
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        watchlist_addresses: watchlist_with_addresses.watchlist_addresses
      })
    end
  end

  def delete_watchlist(conn, %{"id" => watchlist_address_id}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <-
           {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
         {count, _} <- WatchlistAddress.delete(watchlist_address_id, watchlist.id),
         {:watchlist_delete, true} <- {:watchlist_delete, count > 0} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_watchlist(conn, %{
        "address_hash" => address_hash,
        "name" => name,
        "notification_settings" => %{
          "native" => %{
            "incoming" => watch_coin_input,
            "outcoming" => watch_coin_output
          },
          "ERC-20" => %{
            "incoming" => watch_erc_20_input,
            "outcoming" => watch_erc_20_output
          },
          "ERC-721" => %{
            "incoming" => watch_erc_721_input,
            "outcoming" => watch_erc_721_output
          }
          # ,
          # "ERC-1155" => %{
          #   "incoming" => watch_erc_1155_input,
          #   "outcoming" => watch_erc_1155_output
          # }
        },
        "notification_methods" => %{
          "email" => notify_email
        }
      }) do
    watchlist_params = %{
      name: name,
      watch_coin_input: watch_coin_input,
      watch_coin_output: watch_coin_output,
      watch_erc_20_input: watch_erc_20_input,
      watch_erc_20_output: watch_erc_20_output,
      watch_erc_721_input: watch_erc_721_input,
      watch_erc_721_output: watch_erc_721_output,
      watch_erc_1155_input: watch_erc_721_input,
      watch_erc_1155_output: watch_erc_721_output,
      notify_email: notify_email,
      address_hash: address_hash
    }

    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <-
           {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
         {:ok, watchlist_address} <-
           WatchlistAddress.create(Map.put(watchlist_params, :watchlist_id, watchlist.id)) do
      conn
      |> put_status(200)
      |> render(:watchlist_address, %{
        watchlist_address: watchlist_address,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      })
    end
  end

  def update_watchlist(conn, %{
        "id" => watchlist_address_id,
        "address_hash" => address_hash,
        "name" => name,
        "notification_settings" => %{
          "native" => %{
            "incoming" => watch_coin_input,
            "outcoming" => watch_coin_output
          },
          "ERC-20" => %{
            "incoming" => watch_erc_20_input,
            "outcoming" => watch_erc_20_output
          },
          "ERC-721" => %{
            "incoming" => watch_erc_721_input,
            "outcoming" => watch_erc_721_output
          }
          # ,
          # "ERC-1155" => %{
          #   "incoming" => watch_erc_1155_input,
          #   "outcoming" => watch_erc_1155_output
          # }
        },
        "notification_methods" => %{
          "email" => notify_email
        }
      }) do
    watchlist_params = %{
      id: watchlist_address_id,
      name: name,
      watch_coin_input: watch_coin_input,
      watch_coin_output: watch_coin_output,
      watch_erc_20_input: watch_erc_20_input,
      watch_erc_20_output: watch_erc_20_output,
      watch_erc_721_input: watch_erc_721_input,
      watch_erc_721_output: watch_erc_721_output,
      watch_erc_1155_input: watch_erc_721_input,
      watch_erc_1155_output: watch_erc_721_output,
      notify_email: notify_email,
      address_hash: address_hash
    }

    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <-
           {:watchlist, Repo.account_repo().preload(identity, :watchlists)},
         {:ok, watchlist_address} <-
           WatchlistAddress.update(Map.put(watchlist_params, :watchlist_id, watchlist.id)) do
      conn
      |> put_status(200)
      |> render(:watchlist_address, %{
        watchlist_address: watchlist_address,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      })
    end
  end

  def tags_address(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         address_tags <- TagAddress.get_tags_address_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:address_tags, %{address_tags: address_tags})
    end
  end

  def delete_tag_address(conn, %{"id" => tag_id}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- TagAddress.delete(tag_id, identity.id),
         {:tag_delete, true} <- {:tag_delete, count > 0} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_tag_address(conn, %{"address_hash" => address_hash, "name" => name}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, address_tag} <-
           TagAddress.create(%{
             name: name,
             address_hash: address_hash,
             identity_id: identity.id
           }) do
      conn
      |> put_status(200)
      |> render(:address_tag, %{address_tag: address_tag})
    end
  end

  def update_tag_address(conn, %{"id" => tag_id} = attrs) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, address_tag} <-
           TagAddress.update(
             reject_nil_map_values(%{
               id: tag_id,
               name: attrs["name"],
               address_hash: attrs["address_hash"],
               identity_id: identity.id
             })
           ) do
      conn
      |> put_status(200)
      |> render(:address_tag, %{address_tag: address_tag})
    end
  end

  def tags_transaction(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         transaction_tags <- TagTransaction.get_tags_transaction_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:transaction_tags, %{transaction_tags: transaction_tags})
    end
  end

  def delete_tag_transaction(conn, %{"id" => tag_id}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- TagTransaction.delete(tag_id, identity.id),
         {:tag_delete, true} <- {:tag_delete, count > 0} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_tag_transaction(conn, %{"transaction_hash" => tx_hash, "name" => name}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, transaction_tag} <-
           TagTransaction.create(%{
             name: name,
             tx_hash: tx_hash,
             identity_id: identity.id
           }) do
      conn
      |> put_status(200)
      |> render(:transaction_tag, %{transaction_tag: transaction_tag})
    end
  end

  def update_tag_transaction(conn, %{"id" => tag_id} = attrs) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, transaction_tag} <-
           TagTransaction.update(
             reject_nil_map_values(%{
               id: tag_id,
               name: attrs["name"],
               tx_hash: attrs["transaction_hash"],
               identity_id: identity.id
             })
           ) do
      conn
      |> put_status(200)
      |> render(:transaction_tag, %{transaction_tag: transaction_tag})
    end
  end

  def api_keys(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         api_keys <- ApiKey.get_api_keys_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:api_keys, %{api_keys: api_keys})
    end
  end

  def delete_api_key(conn, %{"api_key" => api_key_uuid}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- ApiKey.delete(api_key_uuid, identity.id),
         {:api_key_delete, true} <- {:api_key_delete, count > 0} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_api_key(conn, %{"name" => api_key_name}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, api_key} <-
           ApiKey.create(%{name: api_key_name, identity_id: identity.id}) do
      conn
      |> put_status(200)
      |> render(:api_key, %{api_key: api_key})
    end
  end

  def update_api_key(conn, %{"name" => api_key_name, "api_key" => api_key_value}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, api_key} <-
           ApiKey.update(%{value: api_key_value, name: api_key_name, identity_id: identity.id}) do
      conn
      |> put_status(200)
      |> render(:api_key, %{api_key: api_key})
    end
  end

  def custom_abis(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         custom_abis <- CustomABI.get_custom_abis_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:custom_abis, %{custom_abis: custom_abis})
    end
  end

  def delete_custom_abi(conn, %{"id" => id}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- CustomABI.delete(id, identity.id),
         {:custom_abi_delete, true} <- {:custom_abi_delete, count > 0} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_custom_abi(conn, %{"contract_address_hash" => contract_address_hash, "name" => name, "abi" => abi}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, custom_abi} <-
           CustomABI.create(%{
             name: name,
             address_hash: contract_address_hash,
             abi: abi,
             identity_id: identity.id
           }) do
      conn
      |> put_status(200)
      |> render(:custom_abi, %{custom_abi: custom_abi})
    end
  end

  def update_custom_abi(
        conn,
        %{
          "id" => id
        } = params
      ) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, custom_abi} <-
           CustomABI.update(
             reject_nil_map_values(%{
               id: id,
               name: params["name"],
               address_hash: params["contract_address_hash"],
               abi: params["abi"],
               identity_id: identity.id
             })
           ) do
      conn
      |> put_status(200)
      |> render(:custom_abi, %{custom_abi: custom_abi})
    end
  end

  def public_tags_requests(conn, _params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         public_tags_requests <- PublicTagsRequest.get_public_tags_requests_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:public_tags_requests, %{public_tags_requests: public_tags_requests})
    end
  end

  def delete_public_tags_request(conn, %{"id" => id, "remove_reason" => remove_reason}) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:public_tag_delete, true} <-
           {:public_tag_delete,
            PublicTagsRequest.mark_as_deleted_public_tags_request(%{
              id: id,
              identity_id: identity.id,
              remove_reason: remove_reason
            })} do
      conn
      |> put_status(200)
      |> render(:message, %{message: @ok_message})
    end
  end

  def create_public_tags_request(conn, params) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, public_tags_request} <-
           PublicTagsRequest.create(%{
             full_name: params["full_name"],
             email: params["email"],
             tags: params["tags"],
             website: params["website"],
             additional_comment: params["additional_comment"],
             addresses: params["addresses"],
             company: params["company"],
             is_owner: params["is_owner"],
             identity_id: identity.id
           }) do
      conn
      |> put_status(200)
      |> render(:public_tags_request, %{public_tags_request: public_tags_request})
    end
  end

  def update_public_tags_request(
        conn,
        %{
          "id" => id
        } = params
      ) do
    with {:auth, %{id: uid}} <- {:auth, current_user(conn)},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, public_tags_request} <-
           PublicTagsRequest.update(
             reject_nil_map_values(%{
               id: id,
               full_name: params["full_name"],
               email: params["email"],
               tags: params["tags"],
               website: params["website"],
               additional_comment: params["additional_comment"],
               addresses: params["addresses"],
               company: params["company"],
               is_owner: params["is_owner"],
               identity_id: identity.id
             })
           ) do
      conn
      |> put_status(200)
      |> render(:public_tags_request, %{public_tags_request: public_tags_request})
    end
  end

  def get_csrf(conn, _) do
    with {:auth, %{id: _}} <- {:auth, current_user(conn)} do
      conn
      |> put_resp_header("x-bs-account-csrf", CSRFProtection.get_csrf_token())
      |> put_status(200)
      |> render(:message, %{message: "ok"})
    end
  end

  defp reject_nil_map_values(map) when is_map(map) do
    Map.reject(map, fn {_k, v} -> is_nil(v) end)
  end

  defp preload_watchlist_addresses(watchlist) do
    watchlist
    |> Repo.account_repo().preload(watchlist_addresses: from(wa in WatchlistAddress, order_by: [desc: wa.id]))
  end
end
