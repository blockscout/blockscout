defmodule Explorer.SmartContract.CompilerVersion do
  @moduledoc """
  Adapter for fetching compiler versions from https://solc-bin.ethereum.org/bin/list.json.
  """

  alias Explorer.SmartContract.RustVerifierInterface

  @unsupported_solc_versions ~w(0.1.1 0.1.2)
  @unsupported_vyper_versions ~w(v0.2.9 v0.2.10)

  @doc """
  Fetches a list of compilers from the Ethereum Solidity API.
  """
  @spec fetch_versions(:solc | :vyper) :: {atom, [map]}
  def fetch_versions(compiler) do
    case compiler do
      :solc -> fetch_solc_versions()
      :vyper -> fetch_vyper_versions()
    end
  end

  defp fetch_solc_versions do
    if RustVerifierInterface.enabled?() do
      RustVerifierInterface.get_versions_list()
    else
      headers = [{"Content-Type", "application/json"}]

      case HTTPoison.get(source_url(:solc), headers) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, format_data(body, :solc)}

        {:ok, %{status_code: _status_code, body: body}} ->
          {:error, decode_json(body)["error"]}

        {:error, %{reason: reason}} ->
          {:error, reason}
      end
    end
  end

  defp fetch_vyper_versions do
    if RustVerifierInterface.enabled?() do
      RustVerifierInterface.vyper_get_versions_list()
    else
      headers = [{"Content-Type", "application/json"}]

      case HTTPoison.get(source_url(:vyper), headers) do
        {:ok, %{status_code: 200, body: body}} ->
          {:ok, format_data(body, :vyper)}

        {:ok, %{status_code: _status_code, body: body}} ->
          {:error, decode_json(body)["error"]}

        {:error, %{reason: reason}} ->
          {:error, reason}
      end
    end
  end

  @spec vyper_releases_url :: String.t()
  def vyper_releases_url do
    "https://api.github.com/repos/vyperlang/vyper/releases"
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
            major1 = versions1 |> Enum.at(0) |> parse_integer()
            major2 = versions2 |> Enum.at(0) |> parse_integer()
            minor1 = versions1 |> Enum.at(1) |> parse_integer()
            minor2 = versions2 |> Enum.at(1) |> parse_integer()
            patch1 = versions1 |> Enum.at(2) |> String.split("-") |> Enum.at(0) |> parse_integer()
            patch2 = versions2 |> Enum.at(2) |> String.split("-") |> Enum.at(0) |> parse_integer()

            major1 > major2 || (major1 == major2 && minor1 > minor2) ||
              (major1 == major2 && minor1 == minor2 && patch1 > patch2)
          end)
      end

    ["latest" | versions]
  end

  defp parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
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

  defp decode_json(json) do
    Jason.decode!(json)
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
      :solc ->
        if compiler_version == "latest" do
          compiler_versions = get_compiler_versions(:solc)

          if Enum.count(compiler_versions) > 1 do
            latest_stable_version =
              compiler_versions
              |> Enum.drop(1)
              |> Enum.reduce_while("", fn version, acc ->
                if String.contains?(version, "-nightly") do
                  {:cont, acc}
                else
                  {:halt, version}
                end
              end)

            latest_stable_version
          else
            "latest"
          end
        else
          compiler_version
        end

      :vyper ->
        if compiler_version == "latest" do
          compiler_versions = get_compiler_versions(:vyper)

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

  defp get_compiler_versions(compiler) do
    case fetch_versions(compiler) do
      {:ok, compiler_versions} ->
        compiler_versions

      {:error, _} ->
        []
    end
  end
end
