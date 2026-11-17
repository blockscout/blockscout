# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.Erc404Test do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Token
  alias Explorer.Chain.Token.Erc404

  @retype_advisory_lock_key 7_235_622_386_404

  describe "convert/2" do
    test "waits for an import holding the shared lock without holding back the new imports" do
      token = insert(:token, type: "ERC-721")

      # connections outside the test sandbox stand for import transactions
      in_flight_import = start_connection()
      new_import = start_connection()

      Postgrex.query!(in_flight_import, "SELECT pg_advisory_lock_shared($1)", [@retype_advisory_lock_key])

      conversion = Task.async(fn -> Erc404.convert(token.contract_address_hash) end)

      Process.sleep(300)
      refute Task.yield(conversion, 0)

      # a waiting exclusive request would queue this one behind it
      Postgrex.query!(new_import, "SET lock_timeout = '100ms'", [])
      Postgrex.query!(new_import, "SELECT pg_advisory_lock_shared($1)", [@retype_advisory_lock_key])
      Postgrex.query!(new_import, "SELECT pg_advisory_unlock_shared($1)", [@retype_advisory_lock_key])

      Postgrex.query!(in_flight_import, "SELECT pg_advisory_unlock_shared($1)", [@retype_advisory_lock_key])

      assert Task.await(conversion, 5_000) == 0
      assert %Token{type: "ERC-404"} = Repo.get(Token, token.contract_address_hash)
    end
  end

  # linked to the test process, so it is closed along with it, releasing its locks
  defp start_connection do
    {:ok, connection} =
      Repo.config()
      |> Keyword.drop([:pool, :pool_size, :ownership_timeout, :queue_target, :queue_interval])
      |> Postgrex.start_link()

    connection
  end
end
