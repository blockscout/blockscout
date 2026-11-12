# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.ActionsTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Actions, Config, Result}

  @moduletag :capture_log

  defmodule EchoReporter do
    @behaviour Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter

    @impl true
    def report(results) do
      send(self(), {:reported, results})
      :ok
    end
  end

  defmodule BrokenReporter do
    @behaviour Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter

    @impl true
    def report(_results), do: raise("boom")
  end

  describe "apply/2" do
    test "reports the attacks among the results only" do
      attack = %Result{score: 7}
      benign = %Result{score: 2}

      assert :ok = Actions.apply([attack, benign], %Config{reporter: EchoReporter})

      assert_received {:reported, [^attack]}
    end

    test "reports nothing when no result is an attack" do
      assert :ok = Actions.apply([%Result{score: 4}], %Config{reporter: EchoReporter})

      refute_received {:reported, _}
    end

    test "does nothing when the actions are disabled" do
      assert :ok = Actions.apply([%Result{score: 7}], %Config{reporter: EchoReporter, actions_enabled: false})

      refute_received {:reported, _}
    end

    test "survives a failing reporter" do
      assert :ok = Actions.apply([%Result{score: 7}], %Config{reporter: BrokenReporter})
    end
  end
end
