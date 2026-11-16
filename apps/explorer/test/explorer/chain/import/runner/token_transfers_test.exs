# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.TokenTransfersTest do
  use Explorer.DataCase

  alias Explorer.Chain
  alias Explorer.Chain.Token.Erc404
  alias Explorer.Chain.TokenTransfer

  describe "run/3" do
    test "does not insert the token transfers of the blocks that are not consensus anymore" do
      consensus_block = insert(:block, consensus: true)
      non_consensus_block = insert(:block, consensus: false)
      transaction = :transaction |> insert() |> with_block(consensus_block)
      token = insert(:token)
      from_address = insert(:address)
      to_address = insert(:address)

      token_transfer_params = fn block ->
        %{
          amount: Decimal.new(1),
          block_consensus: true,
          block_hash: block.hash,
          block_number: block.number,
          from_address_hash: from_address.hash,
          log_index: 0,
          to_address_hash: to_address.hash,
          token_contract_address_hash: token.contract_address_hash,
          token_type: "ERC-20",
          transaction_hash: transaction.hash
        }
      end

      assert {:ok, %{token_transfers: [%TokenTransfer{block_hash: block_hash}]}} =
               Chain.import(%{
                 token_transfers: %{
                   params: [token_transfer_params.(consensus_block), token_transfer_params.(non_consensus_block)]
                 }
               })

      assert block_hash == consensus_block.hash
      assert Repo.aggregate(TokenTransfer, :count) == 1
    end
  end

  describe "run/3 with the transfers of a token retyped to ERC-404" do
    setup do
      block = insert(:block, consensus: true)
      transaction = :transaction |> insert() |> with_block(block)

      %{
        block: block,
        transaction: transaction,
        from_address: insert(:address),
        to_address: insert(:address)
      }
    end

    test "gives the ERC-404 shape to legacy legs inserted after the conversion", context do
      token = insert(:token, type: "ERC-404")

      import_transfers([
        erc20_leg(context, token, 0, 5),
        erc721_leg(context, token, 1, 7)
      ])

      assert [
               %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [], amounts: [amount]},
               %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [token_id], amounts: []}
             ] = Repo.all(from(tt in TokenTransfer, order_by: tt.log_index))

      assert Decimal.equal?(amount, 5)
      assert Decimal.equal?(token_id, 7)
    end

    test "keeps the ERC-404 shape of converted transfers re-imported with the legacy shape", context do
      token = insert(:token, type: "ERC-721")

      import_transfers([erc20_leg(context, token, 0, 5), erc721_leg(context, token, 1, 7)])

      Erc404.convert(token.contract_address_hash)

      import_transfers([erc20_leg(context, token, 0, 5), erc721_leg(context, token, 1, 7)])

      assert [
               %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [], amounts: [amount]},
               %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [token_id], amounts: []}
             ] = Repo.all(from(tt in TokenTransfer, order_by: tt.log_index))

      assert Decimal.equal?(amount, 5)
      assert Decimal.equal?(token_id, 7)
    end

    test "leaves the transfers of tokens with a legacy type untouched", context do
      token = insert(:token, type: "ERC-721")

      import_transfers([erc20_leg(context, token, 0, 5)])

      assert [%TokenTransfer{token_type: "ERC-20", amounts: nil, token_ids: nil, amount: amount}] =
               Repo.all(TokenTransfer)

      assert Decimal.equal?(amount, 5)
    end
  end

  defp import_transfers(params) do
    assert {:ok, _} = Chain.import(%{token_transfers: %{params: params}})
  end

  defp erc20_leg(context, token, log_index, amount) do
    context
    |> transfer_params(token, log_index)
    |> Map.merge(%{token_type: "ERC-20", amount: Decimal.new(amount)})
  end

  defp erc721_leg(context, token, log_index, token_id) do
    context
    |> transfer_params(token, log_index)
    |> Map.merge(%{token_type: "ERC-721", token_ids: [token_id]})
  end

  defp transfer_params(context, token, log_index) do
    %{
      block_consensus: true,
      block_hash: context.block.hash,
      block_number: context.block.number,
      from_address_hash: context.from_address.hash,
      log_index: log_index,
      to_address_hash: context.to_address.hash,
      token_contract_address_hash: token.contract_address_hash,
      transaction_hash: context.transaction.hash
    }
  end
end
