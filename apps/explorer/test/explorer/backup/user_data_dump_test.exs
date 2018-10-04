defmodule Explorer.Backup.UserDataDumpTest do
  use Explorer.DataCase, async: false

  describe "generate_and_upload_dump/1" do
    test "return {:ok, results} tupple on success" do
      assert {:ok, _} =
               Explorer.Backup.UserDataDump.generate_and_upload_dump(fn filename ->
                 File.write("/tmp/" <> filename, "")
                 filename
               end)

      refute File.exists?("/tmp/address_names.csv")
      refute File.exists?("/tmp/smart_contracts.csv")
    end

    test "return {:error, exception} on failure" do
      assert {:error, _} = Explorer.Backup.UserDataDump.generate_and_upload_dump(fn _ -> raise ExAws.Error end)
    end
  end

  describe "download_and_restore_dump/1" do
    test "return {:ok, results} tupple on success" do
      assert {:ok, _} =
               Explorer.Backup.UserDataDump.download_and_restore_dump(fn filename ->
                 File.write("/tmp/" <> filename, "")
                 filename
               end)

      refute File.exists?("/tmp/address_names.csv")
      refute File.exists?("/tmp/smart_contracts.csv")
    end

    test "return {:error, exception} on failure" do
      assert {:error, _} = Explorer.Backup.UserDataDump.download_and_restore_dump(fn _ -> raise ExAws.Error end)
    end
  end

  describe "generate_dump/1" do
    test "generate the dump file and return its name when the table name is valid" do
      assert "addresses.csv" == Explorer.Backup.UserDataDump.generate_dump("addresses")
      assert File.exists?("/tmp/addresses.csv")
    end

    test "raise error when table name is invalid" do
      assert_raise(Postgrex.Error, fn -> Explorer.Backup.UserDataDump.generate_dump("address_names2") end)
      refute File.exists?("/tmp/address_names2.csv")
    end
  end

  describe "restore_from_dump/1" do
    test "return file name when restoration runs ok" do
      File.write("/tmp/tokens.csv", "address_hash,name,primary,inserted_at,updated_at")
      assert "tokens.csv" == Explorer.Backup.UserDataDump.restore_from_dump("tokens")
    end

    test "raise error when table name is invalid" do
      File.write("/tmp/address_names3.csv", "address_hash,name,primary,inserted_at,updated_at")
      assert_raise(Postgrex.Error, fn -> Explorer.Backup.UserDataDump.restore_from_dump("address_names3") end)
    end

    test "raise error when file does not exist" do
      assert_raise(File.Error, fn -> Explorer.Backup.UserDataDump.restore_from_dump("smart_contracts") end)
    end
  end

  describe "delete_temp_file/1" do
    test "delete the file and return :ok if exists" do
      File.write("/tmp/address_names.csv", "address_hash,name,primary,inserted_at,updated_at")
      assert :ok == Explorer.Backup.UserDataDump.delete_temp_file("address_names.csv")
      refute File.exists?("/tmp/address_names.csv")
    end

    test "raise error when file does not exist" do
      assert_raise(File.Error, fn -> Explorer.Backup.UserDataDump.delete_temp_file("address_names4.csv") end)
    end
  end
end
