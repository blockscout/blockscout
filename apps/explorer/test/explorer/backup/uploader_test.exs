defmodule Explorer.Backup.UploaderTest do
  use Explorer.DataCase

  alias Plug.Conn

  describe "download_file/1" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ex_aws, :host, "localhost")
      Application.put_env(:ex_aws, :retries, max_attempts: 1)
      Application.put_env(:ex_aws, :s3, scheme: "http://", host: "localhost", port: bypass.port)

      on_exit(fn -> if File.exists?("/tmp/test_file.txt"), do: File.rm!("/tmp/test_file.txt") end)
      {:ok, bypass: bypass}
    end

    test "return file name when request status is 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(200, "")
      end)

      assert "test_file.txt" == Explorer.Backup.Uploader.download_file("test_file.txt")
      assert File.exists?("/tmp/test_file.txt")
    end

    test "raise ExAws.Error when request status is 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(500, "")
      end)

      assert_raise(ExAws.Error, fn -> Explorer.Backup.Uploader.download_file("test_file.txt") end)
    end
  end

  describe "upload_file/1" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ex_aws, :host, "localhost")
      Application.put_env(:ex_aws, :retries, max_attempts: 1)
      Application.put_env(:ex_aws, :s3, scheme: "http://", host: "localhost", port: bypass.port)

      on_exit(fn -> if File.exists?("/tmp/test_file.txt"), do: File.rm!("/tmp/test_file.txt") end)
      {:ok, bypass: bypass}
    end

    test "return file name when request status is 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(200, upload_response_body())
      end)

      File.write("/tmp/test_file.txt", "")

      assert "test_file.txt" = Explorer.Backup.Uploader.upload_file("test_file.txt")
    end

    test "raise ExAws.Error when request status is 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(500, upload_response_body())
      end)

      File.write("/tmp/test_file.txt", "")

      assert_raise(ExAws.Error, fn -> Explorer.Backup.Uploader.upload_file("test_file.txt") end)
    end
  end

  defp upload_response_body() do
    File.read!("./test/support/fixture/backup/upload_response_body.xml")
  end
end
