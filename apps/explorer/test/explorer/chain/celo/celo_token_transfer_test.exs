defmodule Explorer.Chain.CeloTokenTransferTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Chain.TokenTransfer

  describe "TokenTransfers with comments" do
    @long_comment_size 1792

    def token_transfer_params(%{comment: comment} = _params) do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      %{
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        block: transaction.block,
        token: token,
        comment: comment
      }
    end

    test "should insert valid token transfer" do
      params = token_transfer_params(%{comment: "what a nice comment"})
      insert(:token_transfer, params)

      assert [%TokenTransfer{}] = Repo.all(TokenTransfer)
    end

    test "should insert valid token transfer with large comment" do
      comment = String.duplicate("W", @long_comment_size)
      params = token_transfer_params(%{comment: comment})
      insert(:token_transfer, params)

      assert [%TokenTransfer{}] = Repo.all(TokenTransfer)
    end
  end
end
