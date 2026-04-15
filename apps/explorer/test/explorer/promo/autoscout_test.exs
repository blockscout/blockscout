defmodule Explorer.Promo.AutoscoutTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Explorer.Promo.Autoscout

  @promo_line "Deploy Blockscout explorer in 5 minutes at deploy.blockscout.com"

  @moduletag :capture_log

  describe "init/1" do
    test "logs promo and returns the initial state" do
      parent = self()

      log =
        capture_log(fn ->
          pid =
            spawn(fn ->
              send(parent, {:init_result, Autoscout.init(nil)})

              receive do
                :stop -> :ok
              end
            end)

          assert_receive {:init_result, {:ok, %{}}}
          send(pid, :stop)
        end)

      assert log =~ @promo_line
    end
  end

  describe "handle_info/2" do
    test "logs promo and keeps state unchanged" do
      state = %{example: :state}

      log =
        capture_log(fn ->
          assert {:noreply, ^state} = Autoscout.handle_info(:promo, state)
        end)

      assert log =~ @promo_line
    end
  end
end
