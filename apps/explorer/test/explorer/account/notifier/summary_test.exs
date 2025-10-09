defmodule Explorer.Account.Notifier.SummaryTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Account.Notifier.Summary
  alias Explorer.Chain.{TokenTransfer, Transaction, Wei}
  alias Explorer.Repo

  describe "call" do
    test "Coin transaction" do
      transaction =
        %Transaction{
          from_address: from_address,
          to_address: to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      {_, fee} = Transaction.fee(transaction, :gwei)
      amount = Wei.to(transaction.value, :ether)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               }
             ]
    end

    test "Pending Coin transaction (w/o block)" do
      transaction =
        %Transaction{
          from_address: _from_address,
          to_address: _to_address,
          hash: _transaction_hash
        } = insert(:transaction)

      assert Summary.process(transaction) == []
    end

    test "Contract creation transaction" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        %Transaction{
          from_address: _from_address,
          block_number: _block_number,
          hash: transaction_hash
        } =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      {_, fee} = Transaction.fee(transaction, :gwei)
      amount = Wei.to(transaction.value, :ether)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: amount,
                 block_number: block.number,
                 from_address_hash: address.hash,
                 method: "contract_creation",
                 name: "ETH",
                 subject: "Contract creation",
                 to_address_hash: contract_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               }
             ]
    end

    test "ERC-20 Token transfer" do
      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      transfer =
        %TokenTransfer{
          amount: _amount,
          block_number: _block_number,
          from_address: from_address,
          to_address: to_address,
          token: token
        } =
        :token_transfer
        |> insert(transaction: transaction, block: transaction.block, block_number: transaction.block_number)
        |> Repo.preload([
          :token
        ])

      {_, fee} = Transaction.fee(transaction, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "ERC-20",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction.hash,
                 transaction_fee: fee,
                 type: "ERC-20"
               }
             ]
    end

    test "ERC-721 Token transfer" do
      token = insert(:token, type: "ERC-721")

      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      %TokenTransfer{
        amount: _amount,
        block_number: _block_number,
        from_address: from_address,
        to_address: to_address
      } =
        :token_transfer
        |> insert(
          transaction: transaction,
          token_ids: [42],
          token_contract_address: token.contract_address,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {_, fee} = Transaction.fee(transaction, :gwei)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "42",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction.hash,
                 transaction_fee: fee,
                 type: "ERC-721"
               }
             ]
    end

    test "ERC-1155 single Token transfer" do
      token = insert(:token, type: "ERC-1155")

      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      %TokenTransfer{
        amount: _amount,
        block_number: _block_number,
        from_address: from_address,
        to_address: to_address
      } =
        :token_transfer
        |> insert(
          transaction: transaction,
          token_ids: [42],
          token_contract_address: token.contract_address,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {_, fee} = Transaction.fee(transaction, :gwei)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "42",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction.hash,
                 transaction_fee: fee,
                 type: "ERC-1155"
               }
             ]
    end

    test "ERC-1155 multiple Token transfer" do
      token = insert(:token, type: "ERC-1155")

      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      %TokenTransfer{
        amount: _amount,
        block_number: _block_number,
        from_address: from_address,
        to_address: to_address
      } =
        :token_transfer
        |> insert(
          transaction: transaction,
          token_ids: [23, 42],
          token_contract_address: token.contract_address,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {_, fee} = Transaction.fee(transaction, :gwei)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: 0,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "23, 42",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction.hash,
                 transaction_fee: fee,
                 type: "ERC-1155"
               }
             ]
    end

    test "ERC-404 Token transfer with token id" do
      token = insert(:token, type: "ERC-404")

      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      transfer =
        %TokenTransfer{
          amount: _amount,
          block_number: _block_number,
          from_address: from_address,
          to_address: to_address
        } =
        :token_transfer
        |> insert(
          transaction: transaction,
          token_ids: [42],
          token_contract_address: token.contract_address,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {_, fee} = Transaction.fee(transaction, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "42",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "ERC-404"
               }
             ]
    end

    test "ERC-404 Token transfer without token id" do
      token = insert(:token, type: "ERC-404")

      transaction =
        %Transaction{
          from_address: transaction_from_address,
          to_address: transaction_to_address,
          block_number: block_number,
          hash: transaction_hash
        } = with_block(insert(:transaction))

      transaction_amount = Wei.to(transaction.value, :ether)

      transfer =
        %TokenTransfer{
          amount: _amount,
          block_number: _block_number,
          from_address: from_address,
          to_address: to_address
        } =
        :token_transfer
        |> insert(
          transaction: transaction,
          token_ids: [],
          token_contract_address: token.contract_address,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {_, fee} = Transaction.fee(transaction, :gwei)

      token_decimals = Decimal.to_integer(token.decimals)

      decimals = Decimal.new(Integer.pow(10, token_decimals))

      amount = Decimal.div(transfer.amount, decimals)

      assert Summary.process(transaction) == [
               %Summary{
                 amount: transaction_amount,
                 block_number: block_number,
                 from_address_hash: transaction_from_address.hash,
                 method: "transfer",
                 name: "ETH",
                 subject: "Coin transaction",
                 to_address_hash: transaction_to_address.hash,
                 transaction_hash: transaction_hash,
                 transaction_fee: fee,
                 type: "COIN"
               },
               %Summary{
                 amount: amount,
                 block_number: block_number,
                 from_address_hash: from_address.hash,
                 method: "transfer",
                 name: "Infinite Token",
                 subject: "ERC-404",
                 to_address_hash: to_address.hash,
                 transaction_hash: transaction.hash,
                 transaction_fee: fee,
                 type: "ERC-404"
               }
             ]
    end
  end
end
