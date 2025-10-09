defmodule BlockScoutWeb.GraphQL.Schema.Subscription.TokenTransfersTest do
  use BlockScoutWeb.SubscriptionCase
  import Mox

  alias BlockScoutWeb.Notifier

  describe "token_transfers field" do
    setup :set_mox_global

    setup do
      configuration = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, pubsub_server: BlockScoutWeb.PubSub)

      :ok

      on_exit(fn ->
        Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, configuration)
      end)
    end

    test "with valid argument, returns all expected fields", %{socket: socket} do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)
      address_hash = to_string(token_transfer.token_contract_address_hash)

      subscription = """
      subscription ($hash: AddressHash!) {
        token_transfers(token_contract_address_hash: $hash) {
          amount
          from_address_hash
          to_address_hash
          token_contract_address_hash
          transaction_hash
        }
      }
      """

      variables = %{"hash" => address_hash}

      ref = push_doc(socket, subscription, variables: variables)

      assert_reply(ref, :ok, %{subscriptionId: subscription_id})

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

      expected = %{
        result: %{
          data: %{
            "token_transfers" => [
              %{
                "amount" => to_string(token_transfer.amount),
                "from_address_hash" => to_string(token_transfer.from_address_hash),
                "to_address_hash" => to_string(token_transfer.to_address_hash),
                "token_contract_address_hash" => to_string(token_transfer.token_contract_address_hash),
                "transaction_hash" => to_string(token_transfer.transaction_hash)
              }
            ]
          }
        },
        subscriptionId: subscription_id
      }

      assert_push("subscription:data", push)
      assert push == expected
    end

    test "ignores irrelevant tokens", %{socket: socket} do
      transaction = insert(:transaction)
      [token_transfer1, token_transfer2] = insert_list(2, :token_transfer, transaction: transaction)
      address_hash1 = to_string(token_transfer1.token_contract_address_hash)

      subscription = """
      subscription ($hash: AddressHash!) {
        token_transfers(token_contract_address_hash: $hash) {
          amount
          token_contract_address_hash
        }
      }
      """

      variables = %{"hash" => address_hash1}

      ref = push_doc(socket, subscription, variables: variables)

      assert_reply(ref, :ok, %{subscriptionId: _subscription_id})

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer2]})

      refute_push("subscription:data", _push)
    end

    test "ignores non-realtime updates", %{socket: socket} do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)
      address_hash = to_string(token_transfer.token_contract_address_hash)

      subscription = """
      subscription ($hash: AddressHash!) {
        token_transfers(token_contract_address_hash: $hash) {
          amount
          token_contract_address_hash
        }
      }
      """

      variables = %{"hash" => address_hash}

      ref = push_doc(socket, subscription, variables: variables)

      assert_reply(ref, :ok, %{subscriptionId: _subscription_id})

      Notifier.handle_event({:chain_event, :token_transfers, :catchup, [token_transfer]})

      refute_push("subscription:data", _push)
    end
  end
end
