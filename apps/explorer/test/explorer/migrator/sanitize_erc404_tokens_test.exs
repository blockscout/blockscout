# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeErc404TokensTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Token, TokenTransfer}
  alias Explorer.Migrator.{MigrationStatus, SanitizeErc404Tokens}
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  setup :verify_on_exit!
  setup :set_mox_global

  @migration_name "sanitize_erc404_tokens"
  @uint_one "0x0000000000000000000000000000000000000000000000000000000000000001"
  @revert %{error: %{code: -32015, data: "0x", message: "execution reverted"}, jsonrpc: "2.0"}

  setup do
    configuration = Application.get_env(:explorer, SanitizeErc404Tokens)

    Application.put_env(
      :explorer,
      SanitizeErc404Tokens,
      Keyword.merge(configuration || [], batch_size: 1, concurrency: 1, blocks_batch_size: 2)
    )

    on_exit(fn -> Application.put_env(:explorer, SanitizeErc404Tokens, configuration) end)
  end

  describe "tokens emitting the standard Transfer event for both legs" do
    test "converts a token which answers the ERC-404 getters" do
      %{token: token, holder: holder, erc20_transfer: erc20_transfer, erc721_transfer: erc721_transfer} =
        insert_mixed_transfers_token()

      expect_erc404_calls(%{result: @uint_one})

      run_migration()

      assert %Token{type: "ERC-404"} = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)

      assert %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [], amounts: [fungible_amount]} =
               reload_transfer(erc20_transfer)

      assert Decimal.equal?(fungible_amount, 5)

      assert %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [nft_id], amounts: []} =
               reload_transfer(erc721_transfer)

      assert Decimal.equal?(nft_id, 7)

      assert %TokenBalance{token_type: "ERC-404", value: balance_value} =
               Repo.get_by(TokenBalance,
                 address_hash: holder.hash,
                 token_contract_address_hash: token.contract_address_hash
               )

      assert Decimal.equal?(balance_value, 4)

      assert %CurrentTokenBalance{token_type: "ERC-404"} =
               Repo.get_by(CurrentTokenBalance,
                 address_hash: holder.hash,
                 token_contract_address_hash: token.contract_address_hash
               )
    end

    test "leaves a token which doesn't answer the ERC-404 getters untouched" do
      %{token: token, erc20_transfer: erc20_transfer} = insert_mixed_transfers_token()

      expect_erc404_calls(@revert)

      run_migration()

      assert %Token{type: "ERC-721"} = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert %TokenTransfer{token_type: "ERC-20", amounts: nil} = reload_transfer(erc20_transfer)
    end

    test "retries the ERC-404 getters when the node fails to answer" do
      %{token: token} = insert_mixed_transfers_token()

      expect_erc404_calls(%{error: %{code: -32000, message: "header not found"}, jsonrpc: "2.0"})
      expect_erc404_calls(%{result: @uint_one})

      run_migration()

      assert %Token{type: "ERC-404"} = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
    end

    test "completes an interrupted conversion without calls" do
      %{token: token, erc20_transfer: erc20_transfer} = insert_mixed_transfers_token()

      # the token was retyped, but its transfers and balances weren't converted
      Repo.update_all(from(t in Token, where: t.contract_address_hash == ^token.contract_address_hash),
        set: [type: "ERC-404"]
      )

      run_migration()

      assert %TokenTransfer{token_type: "ERC-404", amount: nil} = reload_transfer(erc20_transfer)
    end

    test "leaves the tokens with a complete conversion untouched" do
      token = insert(:token, type: "ERC-404", decimals: 18)
      token_address = Repo.preload(token, :contract_address).contract_address

      # no legacy current token balances, so nothing is left to convert
      erc20_transfer =
        insert(:token_transfer,
          from_address: insert(:address),
          token_contract_address: token_address,
          token_type: "ERC-20",
          amount: Decimal.new(5),
          token_ids: nil
        )

      run_migration()

      assert %TokenTransfer{token_type: "ERC-20"} = reload_transfer(erc20_transfer)
    end

    test "resumes after the last processed candidate" do
      %{token: token_a} = insert_mixed_transfers_token()
      %{token: token_b} = insert_mixed_transfers_token()

      [processed_token, pending_token] = Enum.sort_by([token_a, token_b], &to_string(&1.contract_address_hash))

      MigrationStatus.set_status(@migration_name, "started")

      MigrationStatus.update_meta(@migration_name, %{
        "last_processed" => [to_string(processed_token.contract_address_hash), "calls"]
      })

      expect_erc404_calls(%{result: @uint_one})

      SanitizeErc404Tokens.start_link([])

      assert wait_for_status("completed", 5_000) == "completed"

      assert %Token{type: "ERC-721"} =
               Repo.get_by(Token, contract_address_hash: processed_token.contract_address_hash)

      assert %Token{type: "ERC-404"} = Repo.get_by(Token, contract_address_hash: pending_token.contract_address_hash)
    end

    test "doesn't call ERC-721 tokens without decimals" do
      %{token: token} = insert_mixed_transfers_token(decimals: nil)

      run_migration()

      assert %Token{type: "ERC-721"} = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
    end
  end

  describe "tokens emitting the dedicated ERC-404 events" do
    test "converts the token without calls and re-fetches blocks with uncataloged logs" do
      token = insert(:token, type: "ERC-721", decimals: nil)
      token_address = Repo.preload(token, :contract_address).contract_address

      erc721_transfer =
        insert(:token_transfer,
          from_address: insert(:address),
          token_contract_address: token_address,
          token_type: "ERC-721",
          amount: nil,
          token_ids: [3]
        )

      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log,
        address: token_address,
        first_topic: TokenTransfer.erc404_erc20_transfer_event(),
        transaction: transaction,
        block: block,
        block_number: block.number
      )

      run_migration()

      assert %Token{type: "ERC-404"} = Repo.get_by(Token, contract_address_hash: token.contract_address_hash)
      assert %TokenTransfer{token_type: "ERC-404", amounts: []} = reload_transfer(erc721_transfer)

      assert [%MissingBlockRange{from_number: from_number, to_number: to_number}] = Repo.all(MissingBlockRange)
      assert from_number == block.number and to_number == block.number
    end
  end

  defp insert_mixed_transfers_token(token_attrs \\ []) do
    token = insert(:token, Keyword.merge([type: "ERC-721", decimals: 18], token_attrs))
    token_address = Repo.preload(token, :contract_address).contract_address
    holder = insert(:address)

    erc20_transfer =
      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: token_address,
        to_address: holder,
        token_type: "ERC-20",
        amount: Decimal.new(5),
        token_ids: nil
      )

    erc721_transfer =
      insert(:token_transfer,
        from_address: insert(:address),
        token_contract_address: token_address,
        token_type: "ERC-721",
        amount: nil,
        token_ids: [7]
      )

    insert(:token_balance,
      address: holder,
      token_contract_address_hash: token.contract_address_hash,
      block_number: erc20_transfer.block_number,
      token_type: "ERC-721",
      value: 4
    )

    insert(:address_current_token_balance,
      address: holder,
      token_contract_address_hash: token.contract_address_hash,
      block_number: erc20_transfer.block_number,
      token_type: "ERC-721",
      value: 0
    )

    %{token: token, holder: holder, erc20_transfer: erc20_transfer, erc721_transfer: erc721_transfer}
  end

  defp expect_erc404_calls(response) do
    expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn requests, _opts ->
      {:ok, Enum.map(requests, fn %{id: id} -> Map.put(response, :id, id) end)}
    end)
  end

  defp run_migration do
    assert MigrationStatus.get_status(@migration_name) == nil

    SanitizeErc404Tokens.start_link([])

    assert wait_for_status("completed", 5_000) == "completed"
  end

  defp wait_for_status(_expected_status, timeout) when timeout <= 0, do: MigrationStatus.get_status(@migration_name)

  defp wait_for_status(expected_status, timeout) do
    case MigrationStatus.get_status(@migration_name) do
      ^expected_status ->
        expected_status

      _ ->
        Process.sleep(50)
        wait_for_status(expected_status, timeout - 50)
    end
  end

  defp reload_transfer(%TokenTransfer{} = token_transfer) do
    Repo.get_by(TokenTransfer,
      transaction_hash: token_transfer.transaction_hash,
      block_hash: token_transfer.block_hash,
      log_index: token_transfer.log_index
    )
  end
end
