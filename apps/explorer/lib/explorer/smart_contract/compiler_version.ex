defmodule Explorer.SmartContract.CompilerVersion do
  @moduledoc """
  Adapter for fetching compiler versions from https://solc-bin.ethereum.org/bin/list.json.
  """

  alias Explorer.{Helper, HttpClient}
  alias Explorer.SmartContract.{RustVerifierInterface, StylusVerifierInterface}

  @unsupported_solc_versions ~w(0.1.1 0.1.2)
  @unsupported_vyper_versions ~w(v0.2.9 v0.2.10)

  @doc """
  Fetches a list of compilers from the Ethereum Solidity API.
  """
  @spec fetch_versions(:solc | :vyper | :zk | :stylus) :: {atom, [binary()]}
  def fetch_versions(compiler)

  def fetch_versions(:solc) do
    fetch_compiler_versions(&RustVerifierInterface.get_versions_list/0, :solc)
  end

  def fetch_versions(:vyper) do
    fetch_compiler_versions(&RustVerifierInterface.vyper_get_versions_list/0, :vyper)
  end

  def fetch_versions(:zk) do
    fetch_compiler_versions(&RustVerifierInterface.get_versions_list/0, :zk)
  end

  def fetch_versions(:stylus) do
    fetch_compiler_versions(&StylusVerifierInterface.get_versions_list/0, :stylus)
  end

  @doc """
  Fetches the list of compiler versions for the given compiler.

  ## Parameters

    - compiler: The name of the compiler for which to fetch the version list.

  ## Returns

    - A list of available compiler versions.

  """
  @spec fetch_version_list(:solc | :vyper | :zk | :stylus) :: [binary()]
  def fetch_version_list(compiler) do
    case fetch_versions(compiler) do
      {:ok, compiler_versions} ->
        compiler_versions

      {:error, _} ->
        []
    end
  end

  defp fetch_compiler_versions(compiler_list_fn, :stylus = compiler_type) do
    if StylusVerifierInterface.enabled?() do
      fetch_compiler_versions_sc_verified_enabled(compiler_list_fn, compiler_type)
    else
      {:ok, []}
    end
  end

  defp fetch_compiler_versions(compiler_list_fn, :zk = compiler_type) do
    if RustVerifierInterface.enabled?() do
      fetch_compiler_versions_sc_verified_enabled(compiler_list_fn, compiler_type)
    else
      {:ok, []}
    end
  end

  defp fetch_compiler_versions(compiler_list_fn, compiler_type) do
    if RustVerifierInterface.enabled?() do
      fetch_compiler_versions_sc_verified_enabled(compiler_list_fn, compiler_type)
    else
      headers = [{"Content-Type", "application/json"}]

      case HttpClient.get(source_url(compiler_type), headers) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, format_data(body, compiler_type)}

        {:ok, %{status_code: _status_code, body: body}} ->
          {:error, Helper.decode_json(body)["error"]}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_compiler_versions_sc_verified_enabled(compiler_list_fn, compiler_type) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      # todo: refactor opportunity, currently, Blockscout 2 identical requests to microservice in order to get
      # Solc and Zk compiler versions
      case compiler_list_fn.() do
        {:ok, {solc_compilers, zk_compilers}} ->
          choose_compiler(compiler_type, %{:solc_compilers => solc_compilers, :zk_compilers => zk_compilers})

        _ ->
          {:error, "Verifier microservice is unavailable"}
      end
    else
      compiler_list_fn.()
    end
  end

  defp choose_compiler(compiler_type, compilers) do
    case compiler_type do
      :solc -> {:ok, compilers.solc_compilers}
      :zk -> {:ok, compilers.zk_compilers}
    end
  end

  @spec vyper_releases_url :: String.t()
  def vyper_releases_url do
    "https://api.github.com/repos/vyperlang/vyper/releases?per_page=100"
  end

  defp format_data(json, compiler) do
    versions =
      case compiler do
        :solc ->
          json
          |> Jason.decode!()
          |> Map.fetch!("builds")
          |> remove_unsupported_versions(compiler)
          |> format_versions(compiler)
          |> Enum.reverse()

        :vyper ->
          json
          |> Jason.decode!()
          |> remove_unsupported_versions(compiler)
          |> format_versions(compiler)
          |> Enum.sort(fn version1, version2 ->
            versions1 = String.split(version1, ".")
            versions2 = String.split(version2, ".")
            major1 = versions1 |> Enum.at(0) |> Helper.parse_integer()
            major2 = versions2 |> Enum.at(0) |> Helper.parse_integer()
            minor1 = versions1 |> Enum.at(1) |> Helper.parse_integer()
            minor2 = versions2 |> Enum.at(1) |> Helper.parse_integer()
            patch1 = versions1 |> Enum.at(2) |> String.split("-") |> Enum.at(0) |> Helper.parse_integer()
            patch2 = versions2 |> Enum.at(2) |> String.split("-") |> Enum.at(0) |> Helper.parse_integer()

            major1 > major2 || (major1 == major2 && minor1 > minor2) ||
              (major1 == major2 && minor1 == minor2 && patch1 > patch2)
          end)
      end

    ["latest" | versions]
  end

  @spec remove_unsupported_versions([String.t()], :solc | :vyper) :: [String.t()]
  defp remove_unsupported_versions(builds, compiler) do
    case compiler do
      :solc ->
        Enum.reject(builds, fn %{"version" => version} ->
          Enum.member?(@unsupported_solc_versions, version)
        end)

      :vyper ->
        Enum.reject(builds, fn %{"tag_name" => version} ->
          Enum.member?(@unsupported_vyper_versions, version)
        end)
    end
  end

  defp format_versions(builds, compiler) do
    case compiler do
      :solc ->
        Enum.map(builds, fn build ->
          build
          |> Map.fetch!("path")
          |> String.replace_prefix("soljson-", "")
          |> String.replace_suffix(".js", "")
        end)

      :vyper ->
        Enum.map(builds, fn build ->
          build
          |> Map.fetch!("tag_name")
        end)
    end
  end

  @spec source_url(:solc | :vyper) :: String.t()
  defp source_url(compiler) do
    case compiler do
      :solc ->
        solc_bin_api_url = Application.get_env(:explorer, :solc_bin_api_url)
        "#{solc_bin_api_url}/bin/list.json"

      :vyper ->
        vyper_releases_url()
    end
  end

  def get_strict_compiler_version(compiler, compiler_version) do
    case compiler do
      :solc -> get_solc_latest_stable_version(compiler_version)
      :vyper -> get_vyper_latest_stable_version(compiler_version)
    end
  end

  def get_solc_latest_stable_version(compiler_version) do
    if compiler_version == "latest" do
      get_solc_latest_stable_version_inner()
    else
      compiler_version
    end
  end

  defp get_solc_latest_stable_version_inner do
    compiler_versions = fetch_version_list(:solc)

    if Enum.count(compiler_versions) > 1 do
      compiler_versions
      |> Enum.drop(1)
      |> Enum.reduce_while("", fn version, acc ->
        filter_nightly_version(acc, version)
      end)
    else
      "latest"
    end
  end

  defp filter_nightly_version(acc, version) do
    if String.contains?(version, "-nightly") do
      {:cont, acc}
    else
      {:halt, version}
    end
  end

  def get_vyper_latest_stable_version(compiler_version) do
    if compiler_version == "latest" do
      compiler_versions = fetch_version_list(:vyper)

      if Enum.count(compiler_versions) > 1 do
        latest_stable_version =
          compiler_versions
          |> Enum.at(1)

        latest_stable_version
      else
        "latest"
      end
    else
      compiler_version
    end
  end
end
