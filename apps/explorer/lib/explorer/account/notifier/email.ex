defmodule Explorer.Account.Notifier.Email do
  @moduledoc """
    Composing an email to sendgrid
  """

  require Logger

  alias Explorer.Account.{Identity, Watchlist, WatchlistAddress, WatchlistNotification}
  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias Utils.Helper

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
    |> add_dynamic_field("address_hash", Address.checksum(notification.watchlist_address.address_hash))
    |> add_dynamic_field("address_name", notification.watchlist_address.name)
    |> add_dynamic_field("transaction_hash", to_string(notification.transaction_hash))
    |> add_dynamic_field("from_address_hash", Address.checksum(notification.from_address_hash))
    |> add_dynamic_field("to_address_hash", Address.checksum(notification.to_address_hash))
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
    Helper.instance_url() |> URI.append_path("/address/#{address_hash}") |> to_string()
  end

  defp block_url(notification) do
    Helper.instance_url() |> URI.append_path("/block/#{notification.block_number}") |> to_string()
  end

  defp transaction_url(notification) do
    Helper.instance_url() |> URI.append_path("/tx/#{notification.transaction_hash}") |> to_string()
  end

  defp sender do
    Application.get_env(:explorer, Explorer.Account)[:sendgrid][:sender]
  end

  defp template do
    Application.get_env(:explorer, Explorer.Account)[:sendgrid][:template]
  end
end
