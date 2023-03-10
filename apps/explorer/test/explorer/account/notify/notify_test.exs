defmodule Explorer.Account.Notify.NotifyTest do
  # use ExUnit.Case
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Account.Notifier.Notify
  alias Explorer.Account.{WatchlistAddress, WatchlistNotification}
  alias Explorer.Chain
  alias Explorer.Chain.{Transaction, Wei}
  alias Explorer.Repo

  setup do
    Application.put_env(:explorer, Explorer.Account,
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
        |> Repo.account_repo().one()

      assert notify == [[:ok]]

      assert wn == nil
    end

    test "when address appears in watchlist" do
      wa =
        %WatchlistAddress{address_hash: address_hash} =
        build(:account_watchlist_address)
        |> Repo.account_repo().insert!()

      _watchlist_address = Repo.preload(wa, watchlist: :identity)

      tx =
        %Transaction{
          from_address: _from_address,
          to_address: _to_address,
          block_number: _block_number,
          hash: _tx_hash
        } = with_block(insert(:transaction, to_address: %Chain.Address{hash: address_hash}))

      {_, fee} = Chain.fee(tx, :gwei)
      amount = Wei.to(tx.value, :ether)
      notify = Notify.call([tx])

      wn =
        WatchlistNotification
        |> first
        |> Repo.account_repo().one()

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
