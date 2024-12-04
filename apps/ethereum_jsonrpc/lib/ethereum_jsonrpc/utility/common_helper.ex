defmodule EthereumJSONRPC.Utility.CommonHelper do
  @moduledoc """
    Common helper functions
  """

  alias EthereumJSONRPC.Utility.EndpointAvailabilityObserver

  # converts duration like "5s", "2m", "1h5m" to milliseconds
  @duration_regex ~r/(\d+)([smhSMH]?)/
  def parse_duration(duration) do
    case Regex.scan(@duration_regex, duration) do
      [] ->
        {:error, :invalid_format}

      parts ->
        Enum.reduce(parts, 0, fn [_, number, granularity], acc ->
          acc + convert_to_ms(String.to_integer(number), String.downcase(granularity))
        end)
    end
  end

  @doc """
  Puts value under nested key in keyword.
  Similar to `Kernel.put_in/3` but inserts values in the middle if they're missing
  """
  @spec put_in_keyword_nested(Keyword.t(), [atom()], any()) :: Keyword.t()
  def put_in_keyword_nested(keyword, [last_path], value) do
    Keyword.put(keyword || [], last_path, value)
  end

  def put_in_keyword_nested(keyword, [nearest_path | rest_path], value) do
    Keyword.put(keyword || [], nearest_path, put_in_keyword_nested(keyword[nearest_path], rest_path, value))
  end

  @doc """
  Get available json rpc url from `json_rpc_transport_options` (or global `json_rpc_named_arguments`) of `url_type` type
  based on `EthereumJSONRPC.Utility.EndpointAvailabilityObserver`.
  """
  @spec get_available_url(Keyword.t() | nil, atom()) :: String.t() | nil
  def get_available_url(json_rpc_transport_options \\ nil, url_type \\ :http) do
    transport_options =
      json_rpc_transport_options || Application.get_env(:explorer, :json_rpc_named_arguments)[:transport_options]

    fallback_urls = url_type_to_urls(url_type, transport_options, :fallback)

    url_type
    |> url_type_to_urls(transport_options)
    |> EndpointAvailabilityObserver.maybe_replace_urls(fallback_urls, url_type)
    |> select_single_url()
  end

  @doc """
  Extracts urls corresponding to `url_type` from json rpc transport options
  """
  @spec url_type_to_urls(atom(), Keyword.t(), atom() | String.t()) :: [String.t()]
  def url_type_to_urls(url_type, json_rpc_transport_options, subtype \\ nil) do
    key_prefix = (subtype && "#{subtype}_") || ""
    url_prefix = (url_type == :http && "") || "#{url_type}_"
    urls_key = String.to_existing_atom("#{key_prefix}#{url_prefix}urls")
    json_rpc_transport_options[urls_key]
  end

  defp select_single_url([]), do: nil

  defp select_single_url(urls) do
    Enum.random(urls)
  end

  defp convert_to_ms(number, "s"), do: :timer.seconds(number)
  defp convert_to_ms(number, "m"), do: :timer.minutes(number)
  defp convert_to_ms(number, "h"), do: :timer.hours(number)
end
