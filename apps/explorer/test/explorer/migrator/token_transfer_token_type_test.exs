defmodule Explorer.Migrator.TokenTransferTokenTypeTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.{TokenTransferTokenType, MigrationStatus}
  alias Explorer.Repo

  describe "Migrate token transfers" do
    test "Set token_type and block_consensus for not processed token transfers" do
      %{contract_address_hash: regular_token_hash} = regular_token = insert(:token)

      Enum.each(0..4, fn _x ->
        token_transfer =
          insert(:token_transfer,
            from_address: insert(:address),
            token_contract_address: regular_token.contract_address,
            token_type: nil,
            block_consensus: nil
          )

        assert %{token_type: nil, block_consensus: nil} = token_transfer
      end)

      %{contract_address_hash: erc1155_token_hash} = erc1155_token = insert(:token, type: "ERC-1155")

      Enum.each(0..4, fn _x ->
        token_transfer =
          insert(:token_transfer,
            from_address: insert(:address),
            token_contract_address: erc1155_token.contract_address,
            token_type: nil,
            block_consensus: nil,
            token_ids: nil
          )

        assert %{token_type: nil, block_consensus: nil, token_ids: nil} = token_transfer
      end)

      assert MigrationStatus.get_status("tt_denormalization") == nil

      TokenTransferTokenType.start_link([])
      Process.sleep(100)

      TokenTransfer
      |> where([tt], tt.token_contract_address_hash == ^regular_token_hash)
      |> Repo.all()
      |> Repo.preload([:token, :block])
      |> Enum.each(fn tt ->
        assert %{
                 token_type: token_type,
                 token: %{type: token_type},
                 block_consensus: consensus,
                 block: %{consensus: consensus}
               } = tt

        assert not is_nil(token_type)
        assert not is_nil(consensus)
      end)

      TokenTransfer
      |> where([tt], tt.token_contract_address_hash == ^erc1155_token_hash)
      |> Repo.all()
      |> Repo.preload([:token, :block])
      |> Enum.each(fn tt ->
        assert %{
                 token_type: "ERC-20",
                 token: %{type: "ERC-1155"},
                 block_consensus: consensus,
                 block: %{consensus: consensus}
               } = tt

        assert not is_nil(consensus)
      end)

      assert MigrationStatus.get_status("tt_denormalization") == "completed"
      assert BackgroundMigrations.get_tt_denormalization_finished() == true
    end
  end
end
