defmodule Explorer.Chain.Import.Runner.Signet.FillsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.Signet.Fills, as: FillsRunner
  alias Explorer.Chain.Signet.Fill
  alias Explorer.Repo

  @moduletag :signet

  describe "run/3" do
    test "inserts a new rollup fill" do
      tx_hash = <<1::256>>

      params = [
        %{
          chain_type: :rollup,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          outputs_json: Jason.encode!([%{"token" => "0x5678", "recipient" => "0x9abc", "amount" => "500", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi =
        Multi.new()
        |> FillsRunner.run(params, %{timestamps: timestamps})

      assert {:ok, %{insert_signet_fills: [fill]}} = Repo.transaction(multi)
      assert fill.block_number == 100
      assert fill.chain_type == :rollup
      assert fill.log_index == 0
    end

    test "inserts a new host fill" do
      tx_hash = <<2::256>>

      params = [
        %{
          chain_type: :host,
          block_number: 200,
          transaction_hash: tx_hash,
          log_index: 1,
          outputs_json: Jason.encode!([%{"token" => "0xaaaa", "recipient" => "0xbbbb", "amount" => "1000", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> FillsRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_fills: [fill]}} = Repo.transaction(multi)

      assert fill.block_number == 200
      assert fill.chain_type == :host
    end

    test "same transaction can have fills on different chains" do
      tx_hash = <<3::256>>

      rollup_params = [
        %{
          chain_type: :rollup,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          outputs_json: Jason.encode!([%{"token" => "0x1111", "recipient" => "0x2222", "amount" => "500", "chainId" => "1"}])
        }
      ]

      host_params = [
        %{
          chain_type: :host,
          block_number: 200,
          transaction_hash: tx_hash,
          log_index: 0,  # Same log_index but different chain_type
          outputs_json: Jason.encode!([%{"token" => "0x1111", "recipient" => "0x2222", "amount" => "500", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi1 = Multi.new() |> FillsRunner.run(rollup_params, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi1)

      multi2 = Multi.new() |> FillsRunner.run(host_params, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi2)

      # Should have two fills (one per chain type)
      assert Repo.aggregate(Fill, :count) == 2

      tx_hash_struct = %Explorer.Chain.Hash.Full{byte_count: 32, bytes: tx_hash}

      # Verify both exist
      rollup_fill = Repo.get_by(Fill,
        chain_type: :rollup,
        transaction_hash: tx_hash_struct,
        log_index: 0
      )
      host_fill = Repo.get_by(Fill,
        chain_type: :host,
        transaction_hash: tx_hash_struct,
        log_index: 0
      )

      assert rollup_fill.block_number == 100
      assert host_fill.block_number == 200
    end

    test "handles duplicate fills with upsert on composite primary key" do
      tx_hash = <<4::256>>

      params1 = [
        %{
          chain_type: :rollup,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          outputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "500", "recipient" => "0x5678", "chainId" => "1"}])
        }
      ]

      params2 = [
        %{
          chain_type: :rollup,
          block_number: 101,  # Different block
          transaction_hash: tx_hash,
          log_index: 0,       # Same log_index + chain_type
          outputs_json: Jason.encode!([%{"token" => "0x1234", "amount" => "1000", "recipient" => "0x5678", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi1 = Multi.new() |> FillsRunner.run(params1, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi1)

      multi2 = Multi.new() |> FillsRunner.run(params2, %{timestamps: timestamps})
      {:ok, _} = Repo.transaction(multi2)

      # Should only have one fill for this chain_type + tx_hash + log_index combo
      assert Repo.aggregate(Fill, :count) == 1

      fill = Repo.one!(Fill)
      assert fill.block_number == 101  # Updated
    end

    test "different log_index creates separate fills" do
      tx_hash = <<5::256>>

      params = [
        %{
          chain_type: :rollup,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 0,
          outputs_json: Jason.encode!([%{"token" => "0x1111", "amount" => "500", "recipient" => "0x2222", "chainId" => "1"}])
        },
        %{
          chain_type: :rollup,
          block_number: 100,
          transaction_hash: tx_hash,
          log_index: 1,  # Different log_index
          outputs_json: Jason.encode!([%{"token" => "0x3333", "amount" => "1000", "recipient" => "0x4444", "chainId" => "1"}])
        }
      ]

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> FillsRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_fills: fills}} = Repo.transaction(multi)

      assert length(fills) == 2
      assert Repo.aggregate(Fill, :count) == 2
    end

    test "inserts multiple fills in batch" do
      params =
        for i <- 1..5 do
          %{
            chain_type: if(rem(i, 2) == 0, do: :host, else: :rollup),
            block_number: 100 + i,
            transaction_hash: <<100 + i::256>>,
            log_index: 0,
            outputs_json: Jason.encode!([%{"token" => "0x#{i}", "recipient" => "0x#{i}", "amount" => "#{i * 500}", "chainId" => "1"}])
          }
        end

      timestamps = %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}

      multi = Multi.new() |> FillsRunner.run(params, %{timestamps: timestamps})
      {:ok, %{insert_signet_fills: fills}} = Repo.transaction(multi)

      assert length(fills) == 5
      assert Repo.aggregate(Fill, :count) == 5

      # Verify chain type distribution
      rollup_count = Enum.count(fills, &(&1.chain_type == :rollup))
      host_count = Enum.count(fills, &(&1.chain_type == :host))
      assert rollup_count == 3  # i = 1, 3, 5
      assert host_count == 2    # i = 2, 4
    end
  end

  describe "ecto_schema_module/0" do
    test "returns Fill module" do
      assert FillsRunner.ecto_schema_module() == Fill
    end
  end

  describe "option_key/0" do
    test "returns :signet_fills" do
      assert FillsRunner.option_key() == :signet_fills
    end
  end
end
