defmodule BlockScoutWeb.Account.Api.V1.UserController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Guardian
  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.Api.Key, as: ApiKey
  alias Explorer.Account.CustomABI
  alias Explorer.Account.{Identity, TagAddress, TagTransaction, WatchlistAddress}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market
  alias Explorer.Repo
  alias Guardian.Plug

  action_fallback(BlockScoutWeb.Account.Api.V1.FallbackController)

  def info(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)} do
      conn
      |> put_status(200)
      |> render(:user_info, %{identity: identity})
    end
  end

  def watchlist(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <- {:watchlist, Repo.preload(identity, :watchlists)},
         watchlist_with_addresses <- Repo.preload(watchlist, watchlist_addresses: :address) do
      conn
      |> put_status(200)
      |> render(:watchlist_addresses, %{
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        watchlist_addresses: watchlist_with_addresses.watchlist_addresses
      })
    end
  end

  def delete_watchlist(conn, %{"id" => watchlist_address_id}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <- {:watchlist, Repo.preload(identity, :watchlists)},
         {count, _} <- WatchlistAddress.delete(watchlist_address_id, watchlist.id),
         true <- count > 0 do
      send_resp(conn, 200, "")
    else
      false ->
        conn
        |> put_status(404)
        |> render(:error, %{message: "Watchlist address not found"})
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
    uid = Plug.current_claims(conn)["sub"]

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

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <- {:watchlist, Repo.preload(identity, :watchlists)},
         {:ok, watchlist_address} <-
           WatchlistAddress.create(Map.put(watchlist_params, :watchlist_id, watchlist.id)),
         watchlist_address_preloaded <- Repo.preload(watchlist_address, :address) do
      conn
      |> put_status(200)
      |> render(:watchlist_address, %{
        watchlist_address: watchlist_address_preloaded,
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
    uid = Plug.current_claims(conn)["sub"]

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

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:watchlist, %{watchlists: [watchlist | _]}} <- {:watchlist, Repo.preload(identity, :watchlists)},
         {:ok, watchlist_address} <-
           WatchlistAddress.update(Map.put(watchlist_params, :watchlist_id, watchlist.id)),
         watchlist_address_preloaded <- Repo.preload(watchlist_address, :address) do
      conn
      |> put_status(200)
      |> render(:watchlist_address, %{
        watchlist_address: watchlist_address_preloaded,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      })
    end
  end

  def tags_address(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         address_tags <- TagAddress.get_tags_address_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:address_tags, %{address_tags: address_tags})
    end
  end

  def delete_tag_address(conn, %{"tag_id" => tag_id}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- TagAddress.delete(tag_id, identity.id),
         true <- count > 0 do
      send_resp(conn, 200, "")
    else
      false ->
        conn
        |> put_status(404)
        |> render(:error, %{message: "Tag not found"})
    end
  end

  def create_tag_address(conn, %{"address_hash" => address_hash, "name" => name}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
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

  def tags_transaction(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         transaction_tags <- TagTransaction.get_tags_transaction_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:transaction_tags, %{transaction_tags: transaction_tags})
    end
  end

  def delete_tag_transaction(conn, %{"tag_id" => tag_id}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- TagTransaction.delete(tag_id, identity.id),
         true <- count > 0 do
      send_resp(conn, 200, "")
    else
      false ->
        conn
        |> put_status(404)
        |> render(:error, %{message: "Tag not found"})
    end
  end

  def create_tag_transaction(conn, %{"transaction_hash" => tx_hash, "name" => name}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
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

  def api_keys(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         api_keys <- ApiKey.get_api_keys_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:api_keys, %{api_keys: api_keys})
    end
  end

  def delete_api_key(conn, %{"api_key" => api_key_uuid}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- ApiKey.delete(api_key_uuid, identity.id),
         true <- count > 0 do
      send_resp(conn, 200, "")
    else
      false ->
        conn
        |> put_status(404)
        |> render(:error, %{message: "Api key not found"})
    end
  end

  def create_api_key(conn, %{"name" => api_key_name}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, api_key} <-
           ApiKey.create(%{name: api_key_name, identity_id: identity.id}) do
      conn
      |> put_status(200)
      |> render(:api_key, %{api_key: api_key})
    end
  end

  def update_api_key(conn, %{"name" => api_key_name, "api_key" => api_key_value}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {:ok, api_key} <-
           ApiKey.update(%{value: api_key_value, name: api_key_name, identity_id: identity.id}) do
      conn
      |> put_status(200)
      |> render(:api_key, %{api_key: api_key})
    end
  end

  def custom_abis(conn, _params) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         custom_abis <- CustomABI.get_custom_abis_by_identity_id(identity.id) do
      conn
      |> put_status(200)
      |> render(:custom_abis, %{custom_abis: custom_abis})
    end
  end

  def delete_custom_abi(conn, %{"id" => id}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
         {count, _} <- CustomABI.delete(id, identity.id),
         true <- count > 0 do
      send_resp(conn, 200, "")
    else
      false ->
        conn
        |> put_status(404)
        |> render(:error, %{message: "Custom ABI not found"})
    end
  end

  def create_custom_abi(conn, %{"contract_address_hash" => contract_address_hash, "name" => name, "abi" => abi}) do
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
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
    uid = Plug.current_claims(conn)["sub"]

    with {:identity, [%Identity{} = identity]} <- {:identity, UserFromAuth.find_identity(uid)},
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

  defp reject_nil_map_values(map) when is_map(map) do
    Map.reject(map, fn {_k, v} -> is_nil(v) end)
  end
end
