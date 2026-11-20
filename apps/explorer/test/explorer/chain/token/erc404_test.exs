# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.Erc404Test do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Token, TokenTransfer}
  alias Explorer.Chain.Token.Erc404

  @retype_advisory_lock_key 7_235_622_386_404

  describe "convert/2" do
    test "waits for an import holding the shared lock without holding back the new imports" do
      token = insert(:token, type: "ERC-721")

      # connections outside the test sandbox stand for import transactions
      in_flight_import = start_connection()
      new_import = start_connection()

      Postgrex.query!(in_flight_import, "SELECT pg_advisory_lock_shared($1)", [@retype_advisory_lock_key])

      conversion = Task.async(fn -> Erc404.convert(token.contract_address_hash) end)

      Process.sleep(300)
      refute Task.yield(conversion, 0)

      # a waiting exclusive request would queue this one behind it
      Postgrex.query!(new_import, "SET lock_timeout = '100ms'", [])
      Postgrex.query!(new_import, "SELECT pg_advisory_lock_shared($1)", [@retype_advisory_lock_key])
      Postgrex.query!(new_import, "SELECT pg_advisory_unlock_shared($1)", [@retype_advisory_lock_key])

      Postgrex.query!(in_flight_import, "SELECT pg_advisory_unlock_shared($1)", [@retype_advisory_lock_key])

      assert Task.await(conversion, 5_000) == 0
      assert %Token{type: "ERC-404"} = Repo.get(Token, token.contract_address_hash)
    end

    test "converts in row batches across sparse blocks and blocks with more transfers than a batch" do
      token = insert(:token, type: "ERC-721")
      token_address = Repo.preload(token, :contract_address).contract_address

      dense_block = insert(:block, number: 10)
      far_block = insert(:block, number: 5_000_000)
      newest_block = insert(:block, number: 5_000_001)

      holders = for _ <- 1..3, do: insert(:address)

      dense_transfers =
        for log_index <- 0..4 do
          insert_transfer(token_address, dense_block, log_index, "ERC-20", Enum.at(holders, rem(log_index, 3)))
        end

      far_transfer = insert_transfer(token_address, far_block, 0, "ERC-721", Enum.at(holders, 0))
      newest_transfer = insert_transfer(token_address, newest_block, 0, "ERC-20", Enum.at(holders, 1))

      converted_transfer =
        insert(:token_transfer,
          block: newest_block,
          block_number: newest_block.number,
          transaction: :transaction |> insert() |> with_block(newest_block),
          log_index: 1,
          token_contract_address: token_address,
          token_type: "ERC-404",
          amount: nil,
          amounts: [Decimal.new(9)],
          token_ids: []
        )

      for {holder, block} <- [{Enum.at(holders, 0), dense_block}, {Enum.at(holders, 1), newest_block}] do
        insert(:token_balance,
          address: holder,
          token_contract_address_hash: token.contract_address_hash,
          block_number: block.number,
          token_type: "ERC-721",
          value: 3
        )
      end

      for holder <- holders do
        insert(:address_current_token_balance,
          address: holder,
          token_contract_address_hash: token.contract_address_hash,
          block_number: newest_block.number,
          token_type: "ERC-20",
          value: 1
        )
      end

      assert Erc404.convert(token.contract_address_hash, 2) == 7

      for transfer <- dense_transfers ++ [newest_transfer] do
        assert %TokenTransfer{token_type: "ERC-404", amount: nil, amounts: [amount], token_ids: []} =
                 reload_transfer(transfer)

        assert Decimal.equal?(amount, 5)
      end

      assert %TokenTransfer{token_type: "ERC-404", amount: nil, amounts: [], token_ids: [token_id]} =
               reload_transfer(far_transfer)

      assert Decimal.equal?(token_id, 7)

      assert %TokenTransfer{amounts: [amount]} = reload_transfer(converted_transfer)
      assert Decimal.equal?(amount, 9)

      assert TokenBalance |> Repo.all() |> Enum.map(& &1.token_type) == ["ERC-404", "ERC-404"]
      assert CurrentTokenBalance |> Repo.all() |> Enum.map(& &1.token_type) == ["ERC-404", "ERC-404", "ERC-404"]

      refute Erc404.conversion_pending?(token.contract_address_hash)
      assert Erc404.convert(token.contract_address_hash, 2) == 0
    end
  end

  defp insert_transfer(token_address, block, log_index, "ERC-20", to_address) do
    insert(:token_transfer,
      block: block,
      block_number: block.number,
      transaction: :transaction |> insert() |> with_block(block),
      log_index: log_index,
      token_contract_address: token_address,
      to_address: to_address,
      token_type: "ERC-20",
      amount: Decimal.new(5),
      token_ids: nil
    )
  end

  defp insert_transfer(token_address, block, log_index, "ERC-721", to_address) do
    insert(:token_transfer,
      block: block,
      block_number: block.number,
      transaction: :transaction |> insert() |> with_block(block),
      log_index: log_index,
      token_contract_address: token_address,
      to_address: to_address,
      token_type: "ERC-721",
      amount: nil,
      token_ids: [7]
    )
  end

  defp reload_transfer(%TokenTransfer{block_hash: block_hash, log_index: log_index}),
    do: Repo.one!(from(tt in TokenTransfer, where: tt.block_hash == ^block_hash and tt.log_index == ^log_index))

  # linked to the test process, so it is closed along with it, releasing its locks
  defp start_connection do
    {:ok, connection} =
      Repo.config()
      |> Keyword.drop([:pool, :pool_size, :ownership_timeout, :queue_target, :queue_interval])
      |> Postgrex.start_link()

    connection
  end
end
