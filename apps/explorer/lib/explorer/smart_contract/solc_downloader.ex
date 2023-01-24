defmodule Explorer.SmartContract.SolcDownloader do
  @moduledoc """
  Checks to see if the requested solc compiler version exists, and if not it
  downloads and stores the file.
  """
  use GenServer

  alias Explorer.SmartContract.CompilerVersion

  @latest_compiler_refetch_time :timer.minutes(30)

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end

  def ensure_exists(version) do
    path = file_path(version) |> debug("filepath")

    if File.exists?(path) && version !== "latest" do
      path |> debug("first if")
    else
      compiler_versions =
        case CompilerVersion.fetch_versions(:solc) |> debug("fetch version") do
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
    download_path = "https://solc-bin.ethereum.org/bin/soljson-#{version}.js"

    download_path
    |> HTTPoison.get!([], timeout: 60_000, recv_timeout: 60_000)
    |> debug("HTTPoison download solcjs")
    |> Map.get(:body)
  end
end
