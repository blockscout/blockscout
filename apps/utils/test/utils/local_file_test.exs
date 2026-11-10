# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.LocalFileTest do
  use ExUnit.Case, async: true

  alias Utils.LocalFile

  setup do
    dir = Path.join(System.tmp_dir!(), "local_file_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    %{dir: dir}
  end

  describe "read/2" do
    test "reads a file with an allowed extension", %{dir: dir} do
      path = Path.join(dir, "spec.json")
      File.write!(path, "{}")

      assert LocalFile.read(path, [".json"]) == {:ok, "{}"}
    end

    test "compares the extension case-insensitively", %{dir: dir} do
      path = Path.join(dir, "spec.JSON")
      File.write!(path, "{}")

      assert LocalFile.read(path, [".json"]) == {:ok, "{}"}
    end

    test "rejects a file with an unexpected extension without reading it", %{dir: dir} do
      path = Path.join(dir, "secrets.env")
      File.write!(path, "SECRET=1")

      assert LocalFile.read(path, [".json"]) == {:error, {:invalid_file_extension, ".env", [".json"]}}
    end

    test "rejects a file without an extension" do
      assert LocalFile.read("/etc/passwd", [".json"]) == {:error, {:invalid_file_extension, "", [".json"]}}
    end

    test "rejects a directory named like an allowed file", %{dir: dir} do
      path = Path.join(dir, "folder.json")
      File.mkdir_p!(path)

      assert LocalFile.read(path, [".json"]) == {:error, :not_a_regular_file}
    end

    test "returns a posix error for a missing file", %{dir: dir} do
      assert LocalFile.read(Path.join(dir, "missing.json"), [".json"]) == {:error, :enoent}
    end
  end
end
