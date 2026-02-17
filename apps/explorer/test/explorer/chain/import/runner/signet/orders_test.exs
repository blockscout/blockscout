defmodule Explorer.Chain.Import.Runner.Signet.OrdersTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.Signet.Orders, as: OrdersRunner
  alias Explorer.Chain.Signet.Order
  alias Explorer.Repo

  @moduletag :signet

  describe "run/3" do
    test "inserts a new order" do
      tx_hash = <<1::256>>

      params = [
        %{
          deadline: 1_700_000_000,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          inputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "1000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "500", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi =
        Multi.new()
        |> OrdersRunner.run(params, %{timestamps: timestamps})

      assert {:ok, %{insert_signet_orders: [order]}} = Repo.transaction(multi)
      assert order.block_number == 100
      assert order.deadline == 1_700_000_000
      assert order.log_index == 0
    end

    test "handles duplicate orders with upsert on composite primary key" do
      tx_hash = <<2::256>>

      params = [
        %{
          deadline: 1_700_000_000,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          inputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "1000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "500", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      # Insert first time
      multi1 = Multi.new() |> OrdersRunner.run(params, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi1)

      # Insert second time with same tx_hash + log_index but different data
      updated_params = [
        %{
          deadline: 1_700_000_001,  # Different deadline
          block_number: 101,        # Different block
          transaction_hash: tx_hash,
          log_index: 0,             # Same log_index
          inputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "2000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "1000", "chainId" => "1"}])
        }
      ]

      multi2 = Multi.new() |> OrdersRunner.run(updated_params, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi2)

      # Should only have one order
      assert Repo.aggregate(Order, :count) == 1

      # Order should be updated
      tx_hash_struct = %Explorer.Chain.Hash.Full{byte_count: 32, bytes: tx_hash}
      order = Repo.get_by(Order, transaction_hash: tx_hash_struct, log_index: 0)
      assert order.deadline == 1_700_000_001
      assert order.block_number == 101
    end

    test "different log_index creates separate orders" do
      tx_hash = <<3::256>>

      params = [
        %{
          deadline: 1_700_000_000,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          inputs_json: Jason.encode!([%{"token" => "0x1111", "amount" => "1000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x2222", "recipient" => "0x3333", "amount" => "500", "chainId" => "1"}])
        },
        %{
          deadline: 1_700_000_001,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 1,  # Different log_index
          inputs_json: Jason.encode!([%{"token" => "0x4444", "amount" => "2000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x5555", "recipient" => "0x6666", "amount" => "1000", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> OrdersRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_orders: orders}} = Repo.transaction(multi)

      assert length(orders) == 2
      assert Repo.aggregate(Order, :count) == 2
    end

    test "inserts order with sweep data" do
      tx_hash = <<4::256>>
      sweep_recipient = <<5::160>>
      sweep_token = <<6::160>>

      params = [
        %{
          deadline: 1_700_000_000,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          inputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "1000"}]),
          outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "500", "chainId" => "1"}]),
          sweep_recipient: sweep_recipient,
          sweep_token: sweep_token,
          sweep_amount: Decimal.new("12345")
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> OrdersRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_orders: [order]}} = Repo.transaction(multi)

      assert order.sweep_amount == %Explorer.Chain.Wei{value: Decimal.new("12345")}
    end

    test "inserts multiple orders in batch" do
      params =
        for i <- 1..5 do
          %{
            deadline: 1_700_000_000 + i,
            block_number: 100 + i,
            transaction_hash: <<100 + i::256>>,
            log_index: 0,
            inputs_json: Jason.encode!([%{"token" => "0x#{i}", "amount" => "#{i * 1000}"}]),
            outputs_json: Jason.encode!([%{"token" => "0x#{i}", "recipient" => "0x#{i}", "amount" => "#{i * 500}", "chainId" => "1"}])
          }
        end

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> OrdersRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_orders: orders}} = Repo.transaction(multi)

      assert length(orders) == 5
      assert Repo.aggregate(Order, :count) == 5
    end
  end

  describe "ecto_schema_module/0" do
    test "returns Order module" do
      assert OrdersRunner.ecto_schema_module() == Order
    end
  end

  describe "option_key/0" do
    test "returns :signet_orders" do
      assert OrdersRunner.option_key() == :signet_orders
    end
  end
end
