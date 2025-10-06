defmodule Explorer.Migrator.CeloAccountsTest do
  use Explorer.DataCase, async: false

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type]

  if @chain_type == :celo do
    alias Explorer.Factory
    alias Explorer.Migrator.{CeloAccounts, MigrationStatus}
    alias Explorer.Chain.{Address, Hash}
    alias Explorer.Chain.Celo.{Account, PendingAccountOperation}
    alias Explorer.Chain.Celo.Legacy.Events
    alias Explorer.Repo

    describe "celo_accounts migration" do
      test "enqueues pending operations for new celo addresses" do
        new_address_hash = Factory.address_hash()
        existing_pending_address = insert(:address)
        existing_account_address = insert(:address)

        %PendingAccountOperation{}
        |> PendingAccountOperation.changeset(%{address_hash: existing_pending_address.hash})
        |> Repo.insert!()

        %Account{}
        |> Account.changeset(%{
          address_hash: existing_account_address.hash,
          type: :regular,
          locked_celo: 0,
          nonvoting_locked_celo: 0
        })
        |> Repo.insert!()

        # take AccountCreated topic
        event_topic = Events.account_events() |> Enum.at(3)

        insert(:log, first_topic: event_topic, second_topic: zero_pad(new_address_hash))
        insert(:log, first_topic: event_topic, second_topic: zero_pad(new_address_hash))
        insert(:log, first_topic: event_topic, second_topic: zero_pad(existing_pending_address.hash))
        insert(:log, first_topic: event_topic, second_topic: zero_pad(existing_account_address.hash))

        assert MigrationStatus.set_status("celo_accounts", "started")
        {:ok, pid} = CeloAccounts.start_link([])
        assert Repo.get(Address, new_address_hash) == nil
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000

        pending_addresses =
          PendingAccountOperation
          |> Repo.all()
          |> Enum.map(&Hash.to_string(&1.address_hash))
          |> Enum.sort()

        expected_addresses =
          [existing_pending_address.hash, new_address_hash]
          |> Enum.map(&Hash.to_string/1)
          |> Enum.sort()

        assert pending_addresses == expected_addresses

        assert Repo.get(Address, new_address_hash)
        assert Repo.get(PendingAccountOperation, existing_account_address.hash) == nil
        assert Repo.aggregate(PendingAccountOperation, :count, :address_hash) == 2
        assert MigrationStatus.get_status("celo_accounts") == "completed"
      end
    end

    defp zero_pad(address_hash) do
      <<"0x", rest::binary>> = Hash.to_string(address_hash)
      "0x" <> String.duplicate("0", 24) <> rest
    end
  end
end
