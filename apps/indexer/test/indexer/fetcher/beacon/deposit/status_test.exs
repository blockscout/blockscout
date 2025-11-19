defmodule Indexer.Fetcher.Beacon.Deposit.StatusTest do
  use Explorer.DataCase, async: false

  import Mox
  import Ecto.Query

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.Chain.Wei
  alias Indexer.Fetcher.Beacon.Deposit.Status, as: StatusFetcher
  alias Indexer.Fetcher.Beacon.Deposit.Status.Supervisor, as: StatusSupervisor

  setup :verify_on_exit!
  setup :set_mox_global

  if Application.compile_env(:explorer, :chain_type) == :ethereum do
    @epoch_duration 384

    setup do
      initial_supervisor_env = Application.get_env(:indexer, StatusSupervisor)
      initial_fetcher_env = Application.get_env(:indexer, StatusFetcher)

      Application.put_env(:indexer, StatusSupervisor, initial_supervisor_env |> Keyword.put(:disabled?, false))

      Application.put_env(
        :indexer,
        StatusFetcher,
        initial_fetcher_env |> Keyword.merge(epoch_duration: @epoch_duration, reference_timestamp: 1_722_024_023)
      )

      on_exit(fn ->
        Application.put_env(:indexer, StatusSupervisor, initial_supervisor_env)
        Application.put_env(:indexer, StatusFetcher, initial_fetcher_env)
      end)
    end

    describe "handle_info(:fetch_queued_deposits, _state)" do
      test "marks deposits as completed" do
        # 12405630
        deposit_a =
          insert(:beacon_deposit,
            status: :invalid,
            amount: 1 |> Decimal.new() |> Wei.from(:gwei),
            block_timestamp: DateTime.from_unix!(1_755_691_583)
          )

        # 12405631
        _deposit_b =
          insert(:beacon_deposit,
            status: :pending,
            amount: 2 |> Decimal.new() |> Wei.from(:gwei),
            block_timestamp: DateTime.from_unix!(1_755_691_595)
          )

        # 12405633
        deposit_c =
          insert(:beacon_deposit,
            status: :pending,
            amount: 3 |> Decimal.new() |> Wei.from(:gwei),
            block_timestamp: DateTime.from_unix!(1_755_691_619)
          )

        # 12405634
        deposit_d =
          insert(:beacon_deposit,
            status: :pending,
            amount: 4 |> Decimal.new() |> Wei.from(:gwei),
            block_timestamp: DateTime.from_unix!(1_755_691_631)
          )

        # 12405635
        _deposit_e =
          insert(:beacon_deposit,
            status: :pending,
            amount: 5 |> Decimal.new() |> Wei.from(:gwei),
            block_timestamp: DateTime.from_unix!(1_755_691_643)
          )

        pending_deposits_result =
          """
          {
          "execution_optimistic": false,
          "finalized": false,
          "data": [
          {
                "pubkey": "0xb257656f0a024a5c3be175a3bafd96cfcc452544b0fc6a23bbc39381028a28c10e8bafe6119c34771b5d86c9cae559e5",
                "withdrawal_credentials": "0x01000000000000000000000082ce3e15a02e6a2e5a677d9700fe1390efead8eb",
                "amount": "32000000000",
                "signature": "0xb12eb9bddaf201aac73fb5ba9972ed06093c95a8baa1b5adcf1936ae7f33b0033c34d9e4756567c0424529e2de6774230274b015dfbe848e24a962a8748ea6229a8a87825f979e17d5e66f0246fb5eeb180e318c6574c22339f1cbcf5408a8dd",
                "slot": "12405629"
            },
            {
                "pubkey": "#{deposit_a.pubkey}",
                "withdrawal_credentials": "#{deposit_a.withdrawal_credentials}",
                "amount": "#{deposit_a.amount |> Wei.to(:gwei)}",
                "signature": "#{deposit_a.signature}",
                "slot": "12405630"
            },
            {
                "pubkey": "#{deposit_c.pubkey}",
                "withdrawal_credentials": "#{deposit_c.withdrawal_credentials}",
                "amount": "#{deposit_c.amount |> Wei.to(:gwei)}",
                "signature": "#{deposit_c.signature}",
                "slot": "12405633"
            },
            {
                "pubkey": "#{deposit_d.pubkey}",
                "withdrawal_credentials": "#{deposit_d.withdrawal_credentials}",
                "amount": "#{deposit_d.amount |> Wei.to(:gwei)}",
                "signature": "#{deposit_d.signature}",
                "slot": "12405634"
            }
          ]
          }
          """

        Tesla.Test.expect_tesla_call(
          times: 1,
          returns: fn %{url: "http://localhost:5052/eth/v1/beacon/states/head/pending_deposits"}, _opts ->
            {:ok, %Tesla.Env{status: 200, body: pending_deposits_result}}
          end
        )

        {:noreply, timer} = StatusFetcher.handle_info(:fetch_queued_deposits, nil)

        # if next scheduled call is later than epoch duration something is wrong
        assert Process.read_timer(timer) / 1000 <= @epoch_duration + 1

        assert [
                 %Deposit{status: :invalid},
                 %Deposit{status: :completed},
                 %Deposit{status: :pending},
                 %Deposit{status: :pending},
                 # deposit that appeared after the oldest one in pending deposits
                 # response is not yet reflected on the beacon node and should
                 # not be marked as completed
                 %Deposit{status: :pending}
               ] = Repo.all(from(d in Deposit, order_by: [asc: d.index]))
      end

      test "handles huge amount of data" do
        Repo.query!("SET LOCAL max_stack_depth = '128kB'")

        pending_deposits_response = File.read!("./test/support/fixture/pending_beacon_deposits_response.json")

        Tesla.Test.expect_tesla_call(
          times: 1,
          returns: fn %{url: "http://localhost:5052/eth/v1/beacon/states/head/pending_deposits"}, _opts ->
            {:ok, %Tesla.Env{status: 200, body: pending_deposits_response}}
          end
        )

        {:noreply, _timer} = StatusFetcher.handle_info(:fetch_queued_deposits, nil)
      end
    end
  end
end
