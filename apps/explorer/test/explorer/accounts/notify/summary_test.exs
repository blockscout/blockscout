defmodule Explorer.Accounts.Notify.SummaryTest do
  # use ExUnit.Case
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Accounts.Notifier.Summary
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction, Wei}
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
  end
end
