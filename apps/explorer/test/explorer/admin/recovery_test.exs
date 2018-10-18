defmodule Explorer.Admin.RecoveryTest do
  use ExUnit.Case, async: false

  alias Explorer.Admin.Recovery

  describe "init/1" do
    test "configures the process" do
      assert Recovery.init(nil) == {:ok, %{}}
      assert_received :load_key
    end
  end

  describe "handle_info with :load_key" do
    setup :configure_recovery_file

    test "loads the value from the .recovery file", %{key: key} do
      assert File.exists?(recovery_key_path())
      assert Recovery.handle_info(:load_key, %{}) == {:noreply, %{key: key}}
    end

    test "creates a .recovery if no file present", %{key: key} do
      delete_key()
      refute File.exists?(recovery_key_path())

      assert {:noreply, %{key: new_key}} = Recovery.handle_info(:load_key, %{})
      refute key == new_key
      assert File.exists?(recovery_key_path())
    end
  end

  describe "handle_call with :recovery_key" do
    test "loads the key value store in state" do
      key = "super_secret_key"
      state = %{key: key}
      assert Recovery.handle_call(:recovery_key, self(), state) == {:reply, key, state}
    end
  end

  describe "key/1" do
    setup :configure_recovery_file

    test "returns the key saved in a process", %{key: key} do
      pid = start_supervised!({Recovery, [[], []]})
      assert Recovery.key(pid) == key
      stop_supervised(pid)
    end
  end

  def configure_recovery_file(_context) do
    key = write_key()

    on_exit(fn ->
      delete_key()
    end)

    [key: key]
  end

  defp recovery_key_path do
    base_path = Application.app_dir(:explorer)
    Path.join([base_path, "priv/.recovery"])
  end

  defp write_key do
    file_path = recovery_key_path()
    recovery_key = Recovery.gen_secret()
    File.write(file_path, recovery_key)
    recovery_key
  end

  defp delete_key do
    File.rm(recovery_key_path())
  end
end
