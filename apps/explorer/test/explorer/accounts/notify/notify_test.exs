defmodule Explorer.Accounts.Notify.NotifyTest do
  # use ExUnit.Case
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Accounts.Notifier.Notify
  alias Explorer.Accounts.{WatchlistAddress, WatchlistNotification}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Token, TokenTransfer, Transaction, Wei}
  alias Explorer.Repo

  setup do
    Application.put_env(:explorer, Explorer.Accounts,
      sendgrid: [
        sender: "noreply@blockscout.com",
        template: "d-666"
      ]
    )

    Application.put_env(:explorer, Explorer.Mailer,
      adapter: Bamboo.SendGridAdapter,
      api_key: "SENDGRID_API_KEY"
    )

    Application.put_env(
      :ueberauth,
      Ueberauth,
      providers: [
        auth0: {
          Ueberauth.Strategy.Auth0,
          [callback_url: "callback.url"]
        }
      ],
      logout_url: "logout.url",
      logout_return_to_url: "return.url"
    )
  end

  describe "notify" do
    test "when address not in any watchlist" do
      tx = with_block(insert(:transaction))

      notify = Notify.call([tx])

      wn =
        WatchlistNotification
        |> first
        |> Repo.one()

      assert notify == [[:ok]]

      assert wn == nil
    end

    test "when address apears in watchlist" do
      wa =
        %WatchlistAddress{
          address: address
        } = insert(:account_watchlist_address)

      watchlist_address = Repo.preload(wa, :address, watchlist: :identity)

      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction, to_address: address))

      {_, fee} = Chain.fee(tx, :gwei)
      amount = Wei.to(tx.value, :ether)
      notify = Notify.call([tx])

      wn =
        WatchlistNotification
        |> first
        |> Repo.one()

      assert notify == [[:ok]]

      assert wn.amount == amount
      assert wn.direction == "incoming"
      assert wn.method == "transfer"
      assert wn.subject == "Coin transaction"
      assert wn.tx_fee == fee
      assert wn.type == "COIN"
    end
  end
end
