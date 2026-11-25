# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.WithdrawalsTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.Withdrawals
  alias Explorer.Chain.{Wei, Withdrawal}

  describe "run/3" do
    test "imports regular withdrawals" do
      block = insert(:block)
      address = insert(:address)

      params = [
        withdrawal_params(block, address, %{index: 1, validator_index: 10}),
        withdrawal_params(block, address, %{index: 2, validator_index: 11})
      ]

      assert {:ok, %{withdrawals: imported}} = run_withdrawals(params)

      assert imported |> Enum.map(&to_integer(&1.index)) |> Enum.sort() == [1, 2]
      assert Repo.aggregate(Withdrawal, :count) == 2
    end

    if Application.compile_env(:explorer, :chain_type) == :bera do
      @max_uint64 0xFFFFFFFFFFFFFFFF

      test "imports the EVM inflation withdrawal of every block" do
        address = insert(:address)
        blocks = insert_list(2, :block)

        params =
          blocks
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {block, index} ->
            [
              withdrawal_params(block, address, %{index: @max_uint64, validator_index: @max_uint64}),
              withdrawal_params(block, address, %{index: index, validator_index: 10})
            ]
          end)

        assert {:ok, %{withdrawals: imported}} = run_withdrawals(params)
        assert length(imported) == 4

        inflation_withdrawals = Repo.all(from(w in Withdrawal, where: w.index == ^@max_uint64))

        assert inflation_withdrawals |> Enum.map(& &1.block_number) |> Enum.sort() ==
                 blocks |> Enum.map(& &1.number) |> Enum.sort()

        assert Enum.all?(inflation_withdrawals, &Decimal.equal?(&1.validator_index, @max_uint64))
      end

      test "replaces the withdrawal of the block that lost consensus" do
        address = insert(:address)
        block = insert(:block, consensus: false)
        new_block = insert(:block, number: block.number)

        for block <- [block, new_block] do
          params = [withdrawal_params(block, address, %{index: @max_uint64, validator_index: @max_uint64})]
          assert {:ok, _} = run_withdrawals(params)
        end

        assert [withdrawal] = Repo.all(Withdrawal)
        assert withdrawal.block_hash == new_block.hash
      end
    end
  end

  defp to_integer(%Decimal{} = index), do: Decimal.to_integer(index)
  defp to_integer(index), do: index

  defp withdrawal_params(block, address, overrides) do
    %{
      amount: Wei.from(Decimal.new(1), :ether),
      address_hash: address.hash,
      block_hash: block.hash
    }
    |> Map.merge(chain_type_params(block))
    |> Map.merge(overrides)
  end

  if Application.compile_env(:explorer, :chain_type) == :bera do
    defp chain_type_params(block), do: %{block_number: block.number}
  else
    defp chain_type_params(_block), do: %{}
  end

  defp run_withdrawals(changes_list) do
    Multi.new()
    |> Withdrawals.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
