defmodule Explorer.Accounts.Notify.Email do
  alias Explorer.Accounts.Notify.Notification
  alias Explorer.Accounts.Identity
  alias Explorer.Accounts.Watchlist
  alias Explorer.Accounts.WatchlistAddress
  alias Explorer.Accounts.WatchlistNotification
  alias Explorer.Mailer
  alias Explorer.Repo

  import Bamboo.Email

  def send(notification, %{notify_email: notify}) when notify do
    IO.inspect(notification)

    notification = preload(notification)

    Mailer.deliver_now!(welcome_email(notification))
  end

  def welcome_email(notification) do
    new_email(
      to: email(notification),
      from: "ulyana@blockscout.com",
      subject: subject(notification),
      html_body: "<strong>T#{subject(notification)}</strong>",
      text_body: subject(notification)
    )
  end

  def subject(notification) do
    "[Address Watch Alert] " <>
      "#{notification.amount} " <>
      "#{notification.name} " <>
      "#{affect(notification)} " <>
      "#{place(notification)} " <>
      "#{address(notification)} " <>
      notification.watchlist_address.name
  end

  def email(%WatchlistNotification{
        watchlist_address: %WatchlistAddress{
          watchlist: %Watchlist{
            identity: %Identity{
              email: email
            }
          }
        }
      }),
      do: email

  def address(%WatchlistNotification{
        watchlist_address: %WatchlistAddress{address: address}
      }),
      do: "0x" <> Base.encode16(address.hash.bytes)

  def place(%WatchlistNotification{direction: direction}) do
    case direction do
      "incoming" -> "at"
      "outgoing" -> "from"
      _ -> "unknown"
    end
  end

  def affect(%WatchlistNotification{direction: direction}) do
    case direction do
      "incoming" -> "received"
      "outgoing" -> "sent"
      _ -> "unknown"
    end
  end

  def text_body(notification) do
  end

  def preload(notification) do
    Repo.preload(notification, watchlist_address: [:address, watchlist: :identity])
  end
end
