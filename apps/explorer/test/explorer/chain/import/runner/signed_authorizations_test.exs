# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.SignedAuthorizationsTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.SignedAuthorizations
  alias Explorer.Chain.SignedAuthorization

  describe "run/3" do
    # The status fetcher gets only the rows that the import returns. A reorg clears the status of an authorization,
    # and the import of the next block with the same transaction sends the same row with an empty status.
    test "returns an existing authorization with an empty status when the params are the same" do
      %{transaction_hash: transaction_hash} = authorization = insert(:signed_authorization, status: nil)

      assert {:ok, %{signed_authorizations: [%{transaction_hash: ^transaction_hash, index: 0, status: nil}]}} =
               run_signed_authorizations([SignedAuthorization.to_map(authorization)])
    end

    test "returns an existing authorization and clears its status when the params have an empty status" do
      %{transaction_hash: transaction_hash} = authorization = insert(:signed_authorization, status: :ok)

      assert {:ok, %{signed_authorizations: [%{transaction_hash: ^transaction_hash, index: 0, status: nil}]}} =
               run_signed_authorizations([%{SignedAuthorization.to_map(authorization) | status: nil}])

      assert %{status: nil} = Repo.get_by(SignedAuthorization, transaction_hash: transaction_hash, index: 0)
    end

    test "does not return an existing authorization with a status when the params are the same" do
      authorization = insert(:signed_authorization, authority: nil, status: :invalid_signature)

      assert {:ok, %{signed_authorizations: []}} =
               run_signed_authorizations([SignedAuthorization.to_map(authorization)])
    end
  end

  defp run_signed_authorizations(changes_list) when is_list(changes_list) do
    Multi.new()
    |> SignedAuthorizations.run(changes_list, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
