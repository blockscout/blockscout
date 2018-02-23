defmodule Explorer.Transaction.ServiceTest do
   use Explorer.DataCase

   alias Explorer.Transaction.Service

   describe "internal_transactions/1" do
     test "it returns all internal transactions for a given hash" do
       transaction = insert(:transaction)
       internal_transaction = insert(:internal_transaction, transaction_id: transaction.id)

       result = hd(Service.internal_transactions(transaction.hash))

       assert result.id == internal_transaction.id
     end
   end
end