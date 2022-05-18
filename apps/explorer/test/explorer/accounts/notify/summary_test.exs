defmodule Explorer.Accounts.Notify.SummaryTest do
  # use ExUnit.Case
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Accounts.Notifier.Summary
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Token, TokenTransfer, Transaction, Wei}
  alias Explorer.Repo

  describe "call" do
    test "Coin transaction" do
      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction))

      {_, fee} = Chain.fee(tx, :gwei)
      amount = Wei.to(tx.value, :ether)

      assert Summary.process(tx) == [
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "POA",
                 subject: "Coin transaction",
                 to_address_hash: to_address.hash,
                 transaction_hash: tx_hash,
                 tx_fee: fee,
                 type: "COIN"
               }
             ]
    end

    test "ERC-20 Token transfer" do
      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction))

      transfer =
        %TokenTransfer{
          amount: amount,
          block_number: block_number,
          from_address: from_address,
          to_address: to_address,
          token: token
        } =
        :token_transfer
        |> insert(transaction: tx)
        |> Repo.preload([
          :token
        ])

      {_, fee} = Chain.fee(tx, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transfer) == [
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "ERC-20",
                 to_address_hash: to_address.hash,
                 transaction_hash: tx.hash,
                 tx_fee: fee,
                 type: "ERC-20"
               }
             ]
    end

    test "ERC-721 Token transfer" do
      token = insert(:token, type: "ERC-721")

      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction))

      transfer =
        %TokenTransfer{
          amount: amount,
          block_number: block_number,
          from_address: from_address,
          to_address: to_address
        } =
        :token_transfer
        |> insert(
          transaction: tx,
          token_id: 42,
          token_contract_address: token.contract_address
        )
        |> Repo.preload([
          :token
        ])

      {_, fee} = Chain.fee(tx, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transfer) == [
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "42",
                 to_address_hash: to_address.hash,
                 transaction_hash: tx.hash,
                 tx_fee: fee,
                 type: "ERC-721"
               }
             ]
    end

    test "ERC-1155 single Token transfer" do
      token = insert(:token, type: "ERC-1155")

      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction))

      transfer =
        %TokenTransfer{
          amount: amount,
          block_number: block_number,
          from_address: from_address,
          to_address: to_address
        } =
        :token_transfer
        |> insert(
          transaction: tx,
          token_id: 42,
          token_contract_address: token.contract_address
        )
        |> Repo.preload([
          :token
        ])

      {_, fee} = Chain.fee(tx, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transfer) == [
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "42",
                 to_address_hash: to_address.hash,
                 transaction_hash: tx.hash,
                 tx_fee: fee,
                 type: "ERC-1155"
               }
             ]
    end

    test "ERC-1155 multiple Token transfer" do
      token = insert(:token, type: "ERC-1155")

      tx =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: tx_hash
        } = with_block(insert(:transaction))

      transfer =
        %TokenTransfer{
          amount: amount,
          block_number: block_number,
          from_address: from_address,
          to_address: to_address
        } =
        :token_transfer
        |> insert(
          transaction: tx,
          token_id: nil,
          token_ids: [23, 42],
          token_contract_address: token.contract_address
        )
        |> Repo.preload([
          :token
        ])

      {_, fee} = Chain.fee(tx, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transfer) == [
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "23, 42",
                 to_address_hash: to_address.hash,
                 transaction_hash: tx.hash,
                 tx_fee: fee,
                 type: "ERC-1155"
               }
             ]
    end
  end
end
