# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.RecipientsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Recipients}

  @before_block 1_000

  defp sent_transaction(victim, to, block_number) do
    block = insert(:block, number: block_number)

    :transaction
    |> insert(from_address: victim, to_address: to)
    |> with_block(block)
  end

  # The transaction carrying the transfer is sent to the victim itself, which
  # the set never holds, so that only the transfer's recipient shows up
  defp sent_token_transfer(victim, to, block_number, overrides \\ []) do
    transaction = sent_transaction(victim, victim, block_number)

    insert(
      :token_transfer,
      Keyword.merge(
        [
          from_address: victim,
          to_address: to,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        ],
        overrides
      )
    )
  end

  describe "query/4" do
    test "unions the recipients of sent token transfers and signed transactions" do
      victim = insert(:address)
      transaction_recipient = insert(:address)
      transfer_recipient = insert(:address)

      sent_transaction(victim, transaction_recipient, 10)
      sent_token_transfer(victim, transfer_recipient, 20)

      assert Recipients.query(victim.hash, @before_block, 200) ==
               MapSet.new([transaction_recipient.hash, transfer_recipient.hash])
    end

    test "leaves out the victim itself" do
      victim = insert(:address)
      sent_transaction(victim, victim, 10)

      assert Recipients.query(victim.hash, @before_block, 200) == MapSet.new()
    end

    test "leaves out what happened at or after the bound" do
      victim = insert(:address)
      earlier = insert(:address)
      at_bound = insert(:address)
      later = insert(:address)

      sent_transaction(victim, earlier, 10)
      sent_transaction(victim, at_bound, 50)
      sent_token_transfer(victim, later, 60)

      assert Recipients.query(victim.hash, 50, 200) == MapSet.new([earlier.hash])
    end

    test "leaves out zero-value transfers: they are the poisoning payload" do
      victim = insert(:address)
      mimic = insert(:address)

      sent_token_transfer(victim, mimic, 10, amount: Decimal.new(0))

      assert Recipients.query(victim.hash, @before_block, 200) == MapSet.new()
    end

    test "leaves out transfers emitted from the victim by somebody else's transaction" do
      victim = insert(:address)
      mimic = insert(:address)
      attacker = insert(:address)

      transaction = sent_transaction(attacker, build(:address), 10)

      insert(:token_transfer,
        from_address: victim,
        to_address: mimic,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      assert Recipients.query(victim.hash, @before_block, 200) == MapSet.new()
    end

    test "leaves out transfers of blocks that lost consensus" do
      victim = insert(:address)
      recipient = insert(:address)

      sent_token_transfer(victim, recipient, 10, block_consensus: false)

      assert Recipients.query(victim.hash, @before_block, 200) == MapSet.new()
    end

    test "leaves out pending transactions and contract creations" do
      victim = insert(:address)
      insert(:transaction, from_address: victim, to_address: build(:address))
      sent_transaction(victim, nil, 10)

      assert Recipients.query(victim.hash, @before_block, 200) == MapSet.new()
    end

    test "keeps the latest ones only when over the limit" do
      victim = insert(:address)
      oldest = insert(:address)
      newer = insert(:address)
      newest = insert(:address)

      sent_transaction(victim, oldest, 10)
      sent_transaction(victim, newer, 20)
      sent_transaction(victim, newest, 30)

      assert Recipients.query(victim.hash, @before_block, 2) == MapSet.new([newer.hash, newest.hash])
    end
  end

  describe "fetch/4" do
    setup do
      initial = Application.get_env(:explorer, Recipients) || []
      Application.put_env(:explorer, Recipients, Keyword.merge(initial, enabled: true))

      # the application starts the cache in `:all` mode; start one here only when it did not
      case start_supervised({ConCache, name: Recipients.cache_name(), ttl_check_interval: false}) do
        {:ok, _pid} -> :ok
        {:error, {{:already_started, _pid}, _spec}} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      on_exit(fn -> Application.put_env(:explorer, Recipients, initial) end)

      :ok
    end

    test "serves the second lookup of a victim from the cache" do
      victim = insert(:address)
      recipient = insert(:address)
      sent_transaction(victim, recipient, 10)

      assert Recipients.fetch(victim.hash, @before_block, %Config{}) == MapSet.new([recipient.hash])

      sent_transaction(victim, insert(:address), 20)

      assert Recipients.fetch(victim.hash, @before_block, %Config{}) == MapSet.new([recipient.hash])
    end

    test "queries when the cache is disabled" do
      Application.put_env(:explorer, Recipients, enabled: false)

      victim = insert(:address)
      recipient = insert(:address)
      sent_transaction(victim, recipient, 10)

      assert Recipients.fetch(victim.hash, @before_block, %Config{}) == MapSet.new([recipient.hash])

      other = insert(:address)
      sent_transaction(victim, other, 20)

      assert Recipients.fetch(victim.hash, @before_block, %Config{}) == MapSet.new([recipient.hash, other.hash])
    end
  end
end
