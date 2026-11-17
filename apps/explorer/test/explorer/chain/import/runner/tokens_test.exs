# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.TokensTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Token}
  alias Explorer.Chain.Import.Runner.Tokens

  describe "run/1" do
    test "new tokens have their holder_count set to 0" do
      %Address{hash: contract_address_hash} = insert(:address)
      name = "Name"
      type = "ERC-20"

      assert {:ok, %{tokens: [%Token{holder_count: 0}]}} =
               run_changes(%{contract_address_hash: contract_address_hash, type: type, name: name})
    end

    test "existing tokens with nil holder_count do not have their holder_count set to 0" do
      %Token{contract_address_hash: contract_address_hash, type: type, name: name, holder_count: holder_count} =
        insert(:token)

      assert is_nil(holder_count)

      assert {:ok, %{tokens: [%Token{holder_count: ^holder_count}]}} =
               run_changes(%{contract_address_hash: contract_address_hash, type: type, name: name <> "name"})
    end

    test "existing tokens without nil holder counter do have their holder_count change" do
      %Token{contract_address_hash: contract_address_hash, type: type, name: name, holder_count: holder_count} =
        insert(:token, holder_count: 1)

      refute is_nil(holder_count)

      assert {:ok, %{tokens: [%Token{holder_count: ^holder_count}]}} =
               run_changes(%{contract_address_hash: contract_address_hash, type: type, name: name <> "name"})
    end

    test "keeps the ERC-404 type of a token imported with a legacy type read before its retyping" do
      %Token{contract_address_hash: contract_address_hash, name: name} = insert(:token, type: "ERC-404")

      for legacy_type <- ["ERC-721", "ERC-20"] do
        assert {:ok, _} =
                 run_changes(%{
                   contract_address_hash: contract_address_hash,
                   type: legacy_type,
                   name: name <> legacy_type
                 })

        assert %Token{type: "ERC-404", name: updated_name} = Repo.get(Token, contract_address_hash)
        assert updated_name == name <> legacy_type
      end
    end

    test "returns a cataloged ERC-20 token upgraded to ERC-721, so that the token fetcher catalogs it again" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token, type: "ERC-20", cataloged: true)

      assert {:ok, %{tokens: [%Token{contract_address_hash: ^contract_address_hash, type: "ERC-721"}]}} =
               run_changes(%{contract_address_hash: contract_address_hash, type: "ERC-721"})
    end

    test "still upgrades a legacy token type" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token, type: "ERC-721")

      assert {:ok, _} = run_changes(%{contract_address_hash: contract_address_hash, type: "ERC-404"})
      assert %Token{type: "ERC-404"} = Repo.get(Token, contract_address_hash)
    end
  end

  defp run_changes(changes) when is_map(changes) do
    Multi.new()
    |> Tokens.run([changes], %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
