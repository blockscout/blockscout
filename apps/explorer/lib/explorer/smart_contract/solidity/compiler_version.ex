defmodule Explorer.SmartContract.Solidity.CompilerVersion do
  @moduledoc """
  Adapter for fetching compiler versions from https://solc-bin.ethereum.org/bin/list.json.
  """

  @unsupported_versions ~w(0.1.1 0.1.2)

  @doc """
  Fetches a list of compilers from the Ethereum Solidity API.
  """
  @spec fetch_versions :: {atom, [map]}
  def fetch_versions do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(source_url(), headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, format_data(body)}

      {:ok, %{status_code: _status_code, body: body}} ->
        {:error, decode_json(body)["error"]}

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  defp format_data(json) do
    versions =
      json
      |> Jason.decode!()
      |> Map.fetch!("builds")
      |> remove_unsupported_versions()
      |> format_versions()
      |> Enum.reverse()

    ["latest" | versions]
  end

  defp remove_unsupported_versions(builds) do
    Enum.reject(builds, fn %{"version" => version} ->
      Enum.member?(@unsupported_versions, version)
    end)
  end

  defp format_versions(builds) do
    Enum.map(builds, fn build ->
      build
      |> Map.fetch!("path")
      |> String.replace_prefix("soljson-", "")
      |> String.replace_suffix(".js", "")
    end)
  end

  defp decode_json(json) do
    Jason.decode!(json)
  end

  defp source_url do
    solc_bin_api_url = Application.get_env(:explorer, :solc_bin_api_url)

    "#{solc_bin_api_url}/bin/list.json"
  end

  def get_strict_compiler_version(compiler_version) do
    if compiler_version == "latest" do
      {:ok, compiler_versions} = fetch_versions()

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
  end
end
