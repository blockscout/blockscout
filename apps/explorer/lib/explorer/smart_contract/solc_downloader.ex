defmodule Explorer.SmartContract.SolcDownloader do
  @moduledoc """
  Checks to see if the requested solc compiler version exists, and if not it
  downloads and stores the file.
  """
  use GenServer

  alias Explorer.HttpClient
  alias Explorer.SmartContract.CompilerVersion

  @latest_compiler_refetch_time :timer.minutes(30)

  def ensure_exists(version) do
    path = file_path(version)

    if File.exists?(path) && version !== "latest" do
      path
    else
      compiler_versions =
        case CompilerVersion.fetch_versions(:solc) do
          {:ok, compiler_versions} ->
            compiler_versions

          {:error, _} ->
            []
        end

      if version in compiler_versions do
        # Download in the calling process so it uses the caller's configured
        # Tesla adapter (avoids race conditions when tests override the adapter
        # globally via Application.put_env). The fetch? guard here avoids an
        # unnecessary HTTP request when the file already exists; the same check
        # inside handle_call guards against a concurrent writer finishing first.
        contents = if fetch?(version, path), do: download(version), else: nil
        GenServer.call(__MODULE__, {:ensure_exists, version, contents}, 60_000)
      else
        false
      end
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # sobelow_skip ["Traversal"]
  @impl true
  def init([]) do
    File.mkdir(compiler_dir())

    {:ok, []}
  end

  # sobelow_skip ["Traversal"]
  @impl true
  def handle_call({:ensure_exists, version, contents}, _from, state) do
    path = file_path(version)

    # contents is non-nil only when a download was performed (fetch? was true
    # at call time).  We re-check fetch? here to skip writing when a concurrent
    # caller already wrote the file while this message was queued.
    if contents != nil && fetch?(version, path) do
      temp_path = file_path("#{version}-tmp")

      file = File.open!(temp_path, [:write, :exclusive])

      IO.binwrite(file, contents)

      File.rename(temp_path, path)
    end

    {:reply, path, state}
  end

  defp fetch?("latest", path) do
    case File.stat(path) do
      {:error, :enoent} ->
        true

      {:ok, %{mtime: mtime}} ->
        last_modified = NaiveDateTime.from_erl!(mtime)
        diff = Timex.diff(NaiveDateTime.utc_now(), last_modified, :milliseconds)

        diff > @latest_compiler_refetch_time
    end
  end

  defp fetch?(_, path) do
    not File.exists?(path)
  end

  defp file_path(version) do
    Path.join(compiler_dir(), "#{version}.js")
  end

  defp compiler_dir do
    Application.app_dir(:explorer, "priv/solc_compilers/")
  end

  defp download(version) do
    download_path = "https://binaries.soliditylang.org/bin/soljson-#{version}.js"

    download_path
    |> HttpClient.get!([], timeout: 60_000, recv_timeout: 60_000)
    |> Map.get(:body)
  end
end
