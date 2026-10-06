# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.LockTimeoutTest do
  use Explorer.DataCase

  alias Explorer.Chain.Log
  alias Explorer.Repo.LockTimeout

  describe "run/3" do
    test "returns the function result when no lock is waited for" do
      assert {:ok, false} = LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end)
    end

    test "returns an error instead of waiting while the queried table is locked" do
      with_table_locked("logs", fn ->
        {microseconds, result} = :timer.tc(fn -> LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end) end)

        assert {:error, :lock_timeout} = result
        assert microseconds < :timer.seconds(5) * 1000
      end)
    end

    test "accepts a custom lock timeout" do
      with_table_locked("logs", fn ->
        assert {:error, :lock_timeout} =
                 LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end, lock_timeout: 10)
      end)
    end

    test "leaves the connection usable after the lock timeout" do
      address = insert(:address)

      with_table_locked("logs", fn ->
        assert {:error, :lock_timeout} = LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end)
      end)

      assert Repo.get(Explorer.Chain.Address, address.hash)
      assert {:ok, false} = LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end)
    end

    test "rejects a non-positive lock timeout" do
      assert_raise ArgumentError, fn ->
        LockTimeout.run(Repo, fn repo -> repo.exists?(Log) end, lock_timeout: 0)
      end
    end
  end
end
