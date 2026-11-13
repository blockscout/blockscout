# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.EIP8430TransactionsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain
  alias Explorer.Chain.{Data, EIP8430Transaction}
  alias Explorer.Chain.Import.Runner.EIP8430Transactions
  alias Explorer.Repo

  @payer "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f"
  @sender_auth "0x0000000000000000000000000000000000000001f4646b5a9fcff6e29768f4d61a65b4479946e37a094a3116f5b76486ce466abf1a514af6b3ed852c8b30fcc82fb76a3e8bb6f9c92c2a77e7055c42bdbb8bdccc1b"
  @max_nonce_key Bitwise.bsl(1, 256) - 1

  describe "run/3" do
    test "inserts the fields of an EIP-8430 transaction" do
      transaction = insert(:transaction)

      assert {:ok, %{eip_8430_transactions: [inserted]}} = run([params(transaction.hash)])

      assert inserted.transaction_hash == transaction.hash
      assert inserted.has_named_sender == true
      assert inserted.payer_type == :named
      assert to_string(inserted.payer) == @payer
      assert to_string(inserted.sender_auth) == @sender_auth
      assert inserted.metadata == %Data{bytes: <<>>}
      assert inserted.account_changes == []
    end

    test "handles an empty changes list" do
      assert {:ok, %{eip_8430_transactions: []}} = run([])
    end

    test "replaces the data of a transaction that is imported again" do
      transaction = insert(:transaction)

      insert(:eip_8430_transaction,
        transaction: transaction,
        has_named_sender: true,
        nonce_key: 1,
        valid_before: 5,
        payer_type: :self,
        payer: nil
      )

      changes = %{
        params(transaction.hash)
        | has_named_sender: false,
          nonce_key: 2,
          valid_before: 7,
          payer_type: :open,
          payer: "0x00"
      }

      assert {:ok, %{eip_8430_transactions: [updated]}} = run([changes])

      assert updated.has_named_sender == false
      assert Decimal.eq?(updated.nonce_key, 2)
      assert Decimal.eq?(updated.valid_before, 7)
      assert updated.payer_type == :open
      assert updated.payer == %Data{bytes: <<0>>}

      assert Repo.aggregate(EIP8430Transaction, :count) == 1
    end

    test "stores the maximum nonce key and a validity bound in milliseconds" do
      transaction = insert(:transaction)

      changes = %{params(transaction.hash) | nonce_key: @max_nonce_key, valid_before: 0x1A1C2CDE40D}

      assert {:ok, _} = run([changes])

      stored = Repo.get_by!(EIP8430Transaction, transaction_hash: transaction.hash)

      assert Decimal.eq?(stored.nonce_key, Decimal.new(@max_nonce_key))
      assert Decimal.eq?(stored.valid_before, 0x1A1C2CDE40D)
    end

    test "stores account changes with entries of different forms" do
      transaction = insert(:transaction)

      account_changes = [
        %{"type" => "0x1", "target" => "0x0000000000000000000000000000000000000001"},
        "0xd60194000000000000000000000000000000000000000001"
      ]

      assert {:ok, _} = run([%{params(transaction.hash) | account_changes: account_changes}])

      stored = Repo.get_by!(EIP8430Transaction, transaction_hash: transaction.hash)

      assert stored.account_changes == account_changes
    end

    test "stores the two forms of an absent payer" do
      first_transaction = insert(:transaction)
      second_transaction = insert(:transaction)

      assert {:ok, _} =
               run([
                 %{params(first_transaction.hash) | payer_type: :self, payer: nil},
                 %{params(second_transaction.hash) | payer_type: :self, payer: "0x"}
               ])

      assert Repo.get_by!(EIP8430Transaction, transaction_hash: first_transaction.hash).payer == nil

      assert Repo.get_by!(EIP8430Transaction, transaction_hash: second_transaction.hash).payer ==
               %Data{bytes: <<>>}
    end
  end

  describe "EIP8430Transaction.changeset/2" do
    test "accepts a row with an unknown payer type, with and without payer" do
      transaction_hash = transaction_hash()

      assert changeset(%{params(transaction_hash) | payer_type: :unknown, payer: "0x0102"}).valid?
      assert changeset(%{params(transaction_hash) | payer_type: :unknown, payer: nil}).valid?
    end

    test "rejects a row without a required quantity" do
      for field <- [:nonce_key, :valid_after, :valid_before] do
        changeset = changeset(%{params(transaction_hash()) | field => nil})

        refute changeset.valid?
        assert Keyword.has_key?(changeset.errors, field)
      end
    end

    test "rejects byte fields that are not a hex string of bytes" do
      for field <- [:metadata, :sender_auth, :payer_auth], value <- ["garbage", "0xzz", "0x123"] do
        changeset = changeset(%{params(transaction_hash()) | field => value})

        refute changeset.valid?
        assert Keyword.has_key?(changeset.errors, field)
      end
    end

    test "accepts empty byte fields" do
      attrs = %{params(transaction_hash()) | metadata: "0x", sender_auth: "0x", payer_auth: "0x"}

      assert changeset(attrs).valid?
    end
  end

  describe "Chain.import/1" do
    test "imports a transaction and its EIP-8430 fields in one call" do
      from_address = insert(:address)
      transaction_hash = to_string(transaction_hash())

      assert {:ok, %{eip_8430_transactions: [imported]}} =
               Chain.import(%{
                 transactions: %{
                   params: [
                     %{
                       from_address_hash: to_string(from_address.hash),
                       gas: 0x1255C,
                       gas_price: 0x7744D640,
                       hash: transaction_hash,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0,
                       type: 0x79
                     }
                   ]
                 },
                 eip_8430_transactions: %{params: [params(transaction_hash)]}
               })

      assert to_string(imported.transaction_hash) == transaction_hash
      assert imported.payer_type == :named
    end

    test "does not import a block of data with a malformed byte field" do
      from_address = insert(:address)
      transaction_hash = to_string(transaction_hash())

      assert {:error, [%Ecto.Changeset{valid?: false}]} =
               Chain.import(%{
                 transactions: %{
                   params: [
                     %{
                       from_address_hash: to_string(from_address.hash),
                       gas: 0x1255C,
                       gas_price: 0x7744D640,
                       hash: transaction_hash,
                       input: "0x",
                       nonce: 0,
                       r: 0,
                       s: 0,
                       v: 0,
                       value: 0,
                       type: 0x79
                     }
                   ]
                 },
                 eip_8430_transactions: %{params: [%{params(transaction_hash) | sender_auth: "garbage"}]}
               })

      assert Repo.aggregate(EIP8430Transaction, :count) == 0
    end
  end

  defp run(changes_list) do
    timestamp = DateTime.utc_now()
    options = %{timestamps: %{inserted_at: timestamp, updated_at: timestamp}}

    Multi.new()
    |> EIP8430Transactions.run(changes_list, options)
    |> Repo.transaction()
  end

  defp changeset(attrs), do: EIP8430Transaction.changeset(%EIP8430Transaction{}, attrs)

  defp params(transaction_hash) do
    %{
      transaction_hash: transaction_hash,
      has_named_sender: true,
      nonce_key: 0,
      valid_after: 0,
      valid_before: 0x1A1C2B2A0B1,
      metadata: "0x",
      payer_type: :named,
      payer: @payer,
      sender_auth: @sender_auth,
      payer_auth: "0x01",
      account_changes: []
    }
  end
end
