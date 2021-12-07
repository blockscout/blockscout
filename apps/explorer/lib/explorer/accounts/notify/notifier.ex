defmodule Explorer.Accounts.Notify.Notifier do
  alias Explorer.Accounts.Notify.Email
  alias Explorer.Accounts.Notify.Summary
  alias Explorer.Accounts.WatchlistAddress
  alias Explorer.Accounts.WatchlistNotification
  alias Explorer.Repo

  import Ecto.Query, only: [from: 2]

  def process(%Summary{from_address_hash: nil}), do: nil
  def process(%Summary{to_address_hash: nil}), do: nil

  def process(%Summary{} = summary) do
    incoming_addresses = find_watchlists_addresses(summary.to_address_hash)
    outgoing_addresses = find_watchlists_addresses(summary.from_address_hash)

    Enum.map(incoming_addresses, fn address -> notity_watchlist(address, summary, :incoming) end)

    Enum.map(outgoing_addresses, fn address -> notity_watchlist(address, summary, :outgoing) end)
  end

  def notity_watchlist(%Explorer.Accounts.WatchlistAddress{} = address, summary, direction) do
    notification =
      build_watchlist_notification(
        address,
        summary,
        direction
      )

    Repo.insert(notification)
    Email.send(notification, address)
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

  def is_watched(%WatchlistAddress{} = address, %{type: type}, direction) do
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

  def find_watchlists_addresses(%Explorer.Chain.Hash{} = address_hash) do
    Repo.all(query(address_hash))
  end

  def query(address_hash) do
    from(wa in WatchlistAddress, where: wa.address_hash == ^address_hash)
  end
end
