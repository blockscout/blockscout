defmodule Explorer.Account.Notifier.Notify do
  @moduledoc """
    Composing notification, store and send it to email
  """

  alias Explorer.Account.Notifier.{Email, ForbiddenAddress, Summary}
  alias Explorer.Account.{WatchlistAddress, WatchlistNotification}
  alias Explorer.Chain.Transaction
  alias Explorer.{Mailer, Repo}

  require Logger

  import Ecto.Query, only: [from: 2]
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  def call(nil), do: nil
  def call([]), do: nil

  def call(transactions) when is_list(transactions) do
    Enum.map(transactions, fn transaction -> process(transaction) end)
  end

  defp process(%Transaction{block_timestamp: block_timestamp} = transaction) when not is_nil(block_timestamp) do
    if DateTime.after?(block_timestamp, DateTime.add(DateTime.utc_now(), -1, :day)) do
      Logger.debug(transaction, fetcher: :account)

      transaction
      |> Summary.process()
      |> Enum.map(fn summary -> notify_watchlists(summary) end)
    else
      nil
    end
  end

  defp process(_), do: nil

  defp notify_watchlists(%Summary{from_address_hash: nil}), do: nil
  defp notify_watchlists(%Summary{to_address_hash: nil}), do: nil

  defp notify_watchlists(%Summary{} = summary) do
    incoming_addresses = find_watchlists_addresses(summary.to_address_hash)
    outgoing_addresses = find_watchlists_addresses(summary.from_address_hash)

    Logger.debug("--- filled summary", fetcher: :account)
    Logger.debug(summary, fetcher: :account)

    Enum.each(incoming_addresses, fn address -> notify_watchlist(address, summary, :incoming) end)
    Enum.each(outgoing_addresses, fn address -> notify_watchlist(address, summary, :outgoing) end)
  end

  defp notify_watchlists(nil), do: nil

  defp notify_watchlist(%WatchlistAddress{} = address, summary, direction) do
    case !WatchlistNotification.limit_reached_for_watchlist_id?(address.watchlist_id) &&
           ForbiddenAddress.check(address.address_hash) do
      {:ok, _address_hash} ->
        with %WatchlistNotification{} = notification <-
               build_watchlist_notification(
                 address,
                 summary,
                 direction
               ) do
          notification
          |> query_notification(address)
          |> Repo.account_repo().all()
          |> case do
            [] -> save_and_send_notification(notification, address)
            _ -> :ok
          end
        end

      {:error, _message} ->
        nil

      false ->
        nil
    end
  end

  defp query_notification(notification, watchlist_address) do
    from(wn in WatchlistNotification,
      where:
        wn.watchlist_address_id == ^watchlist_address.id and
          wn.from_address_hash_hash == ^notification.from_address_hash and
          wn.to_address_hash_hash == ^notification.to_address_hash and
          wn.transaction_hash_hash == ^notification.transaction_hash and
          wn.block_number == ^notification.block_number and
          wn.direction == ^notification.direction and
          wn.subject_hash == ^notification.subject and
          wn.amount == ^notification.amount
    )
  end

  defp save_and_send_notification(%WatchlistNotification{} = notification, %WatchlistAddress{} = address) do
    Repo.account_repo().insert(notification)

    email = Email.compose(notification, address)

    if email do
      case Mailer.deliver_now(email, response: true) do
        {:ok, _email, response} ->
          Logger.info("--- email delivery response: SUCCESS", fetcher: :account)
          Logger.info(response, fetcher: :account)

        {:error, error} ->
          Logger.info("--- email delivery response: FAILED", fetcher: :account)
          Logger.info(error, fetcher: :account)
      end
    end
  end

  @doc """
  direction  = :incoming || :outgoing
  """
  def build_watchlist_notification(%Explorer.Account.WatchlistAddress{} = address, summary, direction) do
    if watched?(address, summary, direction) do
      %WatchlistNotification{
        watchlist_address_id: address.id,
        watchlist_id: address.watchlist_id,
        transaction_hash: summary.transaction_hash,
        from_address_hash: summary.from_address_hash,
        to_address_hash: summary.to_address_hash,
        direction: to_string(direction),
        method: summary.method,
        block_number: summary.block_number,
        amount: summary.amount,
        subject: summary.subject,
        transaction_fee: summary.transaction_fee,
        name: summary.name,
        type: summary.type,
        from_address_hash_hash: hash_to_lower_case_string(summary.from_address_hash),
        to_address_hash_hash: hash_to_lower_case_string(summary.to_address_hash),
        transaction_hash_hash: hash_to_lower_case_string(summary.transaction_hash),
        subject_hash: summary.subject
      }
    end
  end

  # credo:disable-for-next-line
  defp watched?(%WatchlistAddress{} = address, %{type: type}, direction) do
    case {type, direction} do
      {"COIN", :incoming} -> address.watch_coin_input
      {"COIN", :outgoing} -> address.watch_coin_output
      {"ERC-20", :incoming} -> address.watch_erc_20_input
      {"ERC-20", :outgoing} -> address.watch_erc_20_output
      {"ERC-721", :incoming} -> address.watch_erc_721_input
      {"ERC-721", :outgoing} -> address.watch_erc_721_output
      {"ERC-1155", :incoming} -> address.watch_erc_1155_input
      {"ERC-1155", :outgoing} -> address.watch_erc_1155_output
      {"ERC-404", :incoming} -> address.watch_erc_404_input
      {"ERC-404", :outgoing} -> address.watch_erc_404_output
    end
  end

  defp find_watchlists_addresses(%Explorer.Chain.Hash{} = address_hash) do
    query = from(wa in WatchlistAddress, where: wa.address_hash_hash == ^address_hash)
    Repo.account_repo().all(query)
  end
end
