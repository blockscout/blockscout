# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Memory.MonitorTest do
  use ExUnit.Case, async: true

  alias Indexer.Memory.Monitor

  describe "parse_cgroup_memory_limit/1" do
    test "parses a valid numeric limit" do
      assert Monitor.parse_cgroup_memory_limit("8589934592\n") == 8_589_934_592
    end

    test "returns nil for \"max\" (cgroup v2 \"no limit\")" do
      assert Monitor.parse_cgroup_memory_limit("max\n") == nil
    end

    test "returns nil for partially numeric content" do
      assert Monitor.parse_cgroup_memory_limit("123garbage") == nil
    end

    test "returns nil for a zero limit" do
      assert Monitor.parse_cgroup_memory_limit("0\n") == nil
    end

    test "returns nil for the cgroup v1 \"no limit\" sentinel" do
      assert Monitor.parse_cgroup_memory_limit("9223372036854771712\n") == nil
    end
  end
end
