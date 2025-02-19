defmodule Explorer.Account.Notifier.Email do
  @moduledoc """
    Composing an email to sendgrid
  """

  require Logger

  alias Explorer.Account.{Identity, Watchlist, WatchlistAddress, WatchlistNotification}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Repo

  import Bamboo.{Email, SendGridHelper}

  def compose(notification, %{notify_email: notify}) when notify do
    notification = preload(notification)

    email = compose_email(notification)
    Logger.debug("--- composed email", fetcher: :account)
    Logger.debug(email, fetcher: :account)
    email
  end

  def compose(_, _), do: nil

  defp compose_email(notification) do
    email = new_email(from: sender(), to: email(notification))

    email
    |> with_template(template())
    |> add_dynamic_field("username", username(notification))
    |> add_dynamic_field("address_hash", address_hash_string(notification))
    |> add_dynamic_field("address_name", notification.watchlist_address.name)
    |> add_dynamic_field("transaction_hash", ExplorerHelper.adds_0x_prefix(notification.transaction_hash))
    |> add_dynamic_field("from_address_hash", ExplorerHelper.adds_0x_prefix(notification.from_address_hash))
    |> add_dynamic_field("to_address_hash", ExplorerHelper.adds_0x_prefix(notification.to_address_hash))
    |> add_dynamic_field("block_number", notification.block_number)
    |> add_dynamic_field("amount", amount(notification))
    |> add_dynamic_field("name", notification.name)
    |> add_dynamic_field("transaction_fee", notification.transaction_fee)
    |> add_dynamic_field("direction", direction(notification))
    |> add_dynamic_field("method", notification.method)
    |> add_dynamic_field("transaction_url", transaction_url(notification))
    |> add_dynamic_field("address_url", address_url(notification.watchlist_address.address_hash))
    |> add_dynamic_field("from_url", address_url(notification.from_address_hash))
    |> add_dynamic_field("to_url", address_url(notification.to_address_hash))
    |> add_dynamic_field("block_url", block_url(notification))
  end

  defp amount(%WatchlistNotification{amount: amount, subject: subject, type: type}) do
    case type do
      "COIN" ->
        amount

      "ERC-20" ->
        amount

      "ERC-721" ->
        "Token ID: " <> subject <> " of "

      "ERC-1155" ->
        "Token ID: " <> subject <> " of "

      "ERC-404" ->
        "Token ID: " <> subject <> " of "
    end
  end

  defp email(%WatchlistNotification{
         watchlist_address: %WatchlistAddress{
           watchlist: %Watchlist{
             identity: %Identity{
               email: email
             }
           }
         }
       }),
       do: email

  defp username(%WatchlistNotification{
         watchlist_address: %WatchlistAddress{
           watchlist: %Watchlist{
             identity: %Identity{
               name: name
             }
           }
         }
       }),
       do: name

  defp address_hash_string(%WatchlistNotification{
         watchlist_address: %WatchlistAddress{address_hash: address_hash}
       }),
       do: ExplorerHelper.adds_0x_prefix(address_hash.bytes)

  defp direction(notification) do
    affect(notification) <> " " <> place(notification)
  end

  defp place(%WatchlistNotification{direction: direction}) do
    case direction do
      "incoming" -> "at"
      "outgoing" -> "from"
      _ -> "unknown"
    end
  end

  defp affect(%WatchlistNotification{direction: direction}) do
    case direction do
      "incoming" -> "received"
      "outgoing" -> "sent"
      _ -> "unknown"
    end
  end

  defp preload(notification) do
    Repo.account_repo().preload(notification, watchlist_address: [watchlist: :identity])
  end

  defp address_url(address_hash) do
    uri() |> URI.append_path("/address/#{address_hash}") |> to_string()
  end

  defp block_url(notification) do
    uri() |> URI.append_path("/block/#{notification.block_number}") |> to_string()
  end

  defp transaction_url(notification) do
    uri() |> URI.append_path("/tx/#{notification.transaction_hash}") |> to_string()
  end

  defp url_params do
    Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url]
  end

  defp uri do
    %URI{scheme: scheme(), host: host(), port: port(), path: path()}
  end

  defp scheme do
    Keyword.get(url_params(), :scheme, "http")
  end

  defp host do
    url_params()[:host]
  end

  defp port do
    url_params()[:http][:port]
  end

  defp path do
    raw_path = url_params()[:path]

    if raw_path |> String.ends_with?("/") do
      raw_path |> String.slice(0..-2//1)
    else
      raw_path
    end
  end

  defp sender do
    Application.get_env(:explorer, Explorer.Account)[:sendgrid][:sender]
  end

  defp template do
    Application.get_env(:explorer, Explorer.Account)[:sendgrid][:template]
  end
end
