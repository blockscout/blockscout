# credo:disable-for-this-file Credo.Check.Warning.IoInspect
defmodule Mix.Tasks.CoreContracts do
  use Mix.Task

  import Explorer.Celo.CoreContracts
  alias HTTPoison.Response

  @moduledoc "Builds core contract cache initial values"
  @shortdoc "Create a core contract address cache for a given blockchain endpoint"
  def run([url]) do
    HTTPoison.start()

    url
    |> full_cache_build()
    |> IO.inspect()
  end

  def full_cache_build(url) do
    Enum.reduce(contract_list(), {}, fn name, acc ->
      Map.put(acc, name, query_registry(name, url))
    end)
  end

  @address_for_string_signature "getAddressForString(string)"
  def request_for_name(name, id \\ 777) do
    request_data =
      @address_for_string_signature
      |> ABI.encode([name])
      |> Base.encode16(case: :lower)
      |> then(&("0x" <> &1))

    %{jsonrpc: "2.0", method: "eth_call", params: [%{to: registry_address(), data: request_data}, "latest"], id: id}
    |> Jason.encode!()
  end

  def query_registry(name, registry_url) do
    name
    |> request_for_name()
    |> perform_request(registry_url)
    |> transform_result()
  end

  defp perform_request(json_body, source_url) do
    case HTTPoison.post(source_url, json_body, [{"Content-Type", "application/json"}]) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, Jason.decode!(body, keys: :atoms)}

      e ->
        e
    end
  end

  defp transform_result({:ok, %{result: address}}) do
    address
    # last 40 characters of response
    |> String.slice(-40..-1)
    |> then(&("0x" <> &1))
  end
end
