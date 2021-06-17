defmodule Explorer.SmartContract.VyperDownloader do
  @moduledoc """
  Checks to see if the requested Vyper compiler version exists, and if not it
  downloads and stores the file.
  """
  use GenServer

  alias Explorer.SmartContract.CompilerVersion

  @latest_compiler_refetch_time :timer.minutes(30)

  def ensure_exists(version) do
    path = file_path(version)

    if File.exists?(path) && version !== "latest" do
      path
    else
      compiler_versions =
        case CompilerVersion.fetch_versions(:vyper) do
          {:ok, compiler_versions} ->
            compiler_versions

          {:error, _} ->
            []
        end

      if version in compiler_versions do
        GenServer.call(__MODULE__, {:ensure_exists, version}, 60_000)
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
  def handle_call({:ensure_exists, version}, _from, state) do
    path = file_path(version)

    if fetch?(version, path) do
      temp_path = file_path("#{version}-tmp")

      contents = download(version)

      file = File.open!(temp_path, [:write, :exclusive])

      IO.binwrite(file, contents)

      File.close(file)

      File.rename(temp_path, path)
      System.cmd("chmod", ["+x", path])
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
    Path.join(compiler_dir(), "#{version}")
  end

  defp compiler_dir do
    Application.app_dir(:explorer, "priv/vyper_compilers/")
  end

  defp download(version) do
    version = CompilerVersion.get_strict_compiler_version(:vyper, version)
    releases_path = CompilerVersion.vyper_releases_url()

    releases_body =
      releases_path
      |> HTTPoison.get!([], timeout: 60_000, recv_timeout: 60_000)
      |> Map.get(:body)
      |> Jason.decode!()

    release =
      releases_body
      |> Enum.find(fn release ->
        Map.get(release, "tag_name") == version
      end)

    release_assets = Map.get(release, "assets")

    download_path =
      Enum.reduce_while(release_assets, "", fn asset, acc ->
        browser_download_url = Map.get(asset, "browser_download_url")

        # darwin is for local tests
        # if browser_download_url =~ "darwin" do
        if browser_download_url =~ "linux" do
          {:halt, browser_download_url}
        else
          {:cont, acc}
        end
      end)

    download_path
    |> HTTPoison.get!([], timeout: 60_000, recv_timeout: 60_000, follow_redirect: true, hackney: [force_redirect: true])
    |> Map.get(:body)
  end
end
