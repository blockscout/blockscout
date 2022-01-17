defmodule Explorer.Accounts.Notify.Notifier do
  @moduledoc """
    Composing notification, store and send it to email
  """

  alias Explorer.Accounts.Notify.{Email, Summary}
  alias Explorer.Accounts.{WatchlistAddress, WatchlistNotification}
  alias Explorer.Chain.Transaction
  alias Explorer.{Mailer, Repo}

  import Ecto.Query, only: [from: 2]

  def notify(nil), do: nil
  def notify([]), do: nil

  def notify(transactions) when is_list(transactions) do
    Enum.map(transactions, fn transaction -> process(transaction) end)
  end

  defp process(%Transaction{} = transaction) do
    transaction
    |> Summary.process()
    |> Enum.map(fn summary -> notify_watchlists(summary) end)
  end

  defp process(_), do: nil

  defp notify_watchlists(%Summary{from_address_hash: nil}), do: nil
  defp notify_watchlists(%Summary{to_address_hash: nil}), do: nil

  defp notify_watchlists(%Summary{} = summary) do
    incoming_addresses = find_watchlists_addresses(summary.to_address_hash)
    outgoing_addresses = find_watchlists_addresses(summary.from_address_hash)

    Enum.each(incoming_addresses, fn address -> notity_watchlist(address, summary, :incoming) end)
    Enum.each(outgoing_addresses, fn address -> notity_watchlist(address, summary, :outgoing) end)
  end

  defp notity_watchlist(%Explorer.Accounts.WatchlistAddress{} = address, summary, direction) do
    notification =
      build_watchlist_notification(
        address,
        summary,
        direction
      )

    Repo.insert(notification)

    email = Email.compose(notification, address)

    case Mailer.deliver_now(email, response: true) do
      {:ok, _email, response} ->
        AccountLogger.info("--- email delivery response: SUCCESS")
        AccountLogger.info(response)

      {:error, error} ->
        AccountLogger.info("--- email delivery response: FAILED")
        AccountLogger.info(error)
    end
  end

  @doc """
  direction  = :incoming || :outgoing
  """
  def build_watchlist_notification(%Explorer.Accounts.WatchlistAddress{} = address, summary, direction) do
    if is_watched(address, summary, direction) do
      %WatchlistNotification{
        watchlist_address_id: address.id,
        transaction_hash: summary.transaction_hash,
        from_address_hash: summary.from_address_hash,
        to_address_hash: summary.to_address_hash,
        direction: to_string(direction),
        method: summary.method,
        block_number: summary.block_number,
        amount: summary.amount,
        tx_fee: summary.tx_fee,
        name: summary.name,
        type: summary.type
      }
    end
  end

  defp is_watched(%WatchlistAddress{} = address, %{type: type}, direction) do
    case {type, direction} do
      {"COIN", :incoming} -> address.watch_coin_input
      {"COIN", :outgoing} -> address.watch_coin_output
      {"ERC-20", :incoming} -> address.watch_erc_20_input
      {"ERC-20", :outgoing} -> address.watch_erc_20_output
      {"ERC-721", :incoming} -> address.watch_erc_721_input
      {"ERC-721", :outgoing} -> address.watch_erc_721_output
      {"ERC-1155", :incoming} -> address.watch_erc_1155_input
      {"ERC-1155", :outgoing} -> address.watch_erc_1155_output
    end
  end

  defp find_watchlists_addresses(%Explorer.Chain.Hash{} = address_hash) do
    query = from(wa in WatchlistAddress, where: wa.address_hash == ^address_hash)
    Repo.all(query)
  end
end
