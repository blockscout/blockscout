defmodule EthereumJSONRPC.Utility.CommonHelperTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Utility.{EndpointAvailabilityObserver, CommonHelper}

  @options [
    urls: ["url_1", "url_2"],
    trace_urls: ["trace_url_1", "trace_url_2"],
    eth_call_urls: ["eth_call_url_1", "eth_call_url_2"],
    fallback_urls: ["fallback_url_1", "fallback_url_2"],
    fallback_trace_urls: ["fallback_trace_url_1", "fallback_trace_url_2"],
    fallback_eth_call_urls: ["fallback_ec_url_1", "fallback_ec_url_2"]
  ]

  test "url_type_to_urls/3" do
    assert ["url_1", "url_2"] = CommonHelper.url_type_to_urls(:http, @options)
    assert ["trace_url_1", "trace_url_2"] = CommonHelper.url_type_to_urls(:trace, @options)
    assert ["eth_call_url_1", "eth_call_url_2"] = CommonHelper.url_type_to_urls(:eth_call, @options)
    assert ["fallback_url_1", "fallback_url_2"] = CommonHelper.url_type_to_urls(:http, @options, :fallback)
    assert ["fallback_trace_url_1", "fallback_trace_url_2"] = CommonHelper.url_type_to_urls(:trace, @options, :fallback)
    assert ["fallback_ec_url_1", "fallback_ec_url_2"] = CommonHelper.url_type_to_urls(:eth_call, @options, :fallback)
  end

  test "get_available_url/2" do
    EndpointAvailabilityObserver.start_link([])

    assert CommonHelper.get_available_url(@options, :http) in @options[:urls]
    assert CommonHelper.get_available_url(@options, :trace) in @options[:trace_urls]
    assert CommonHelper.get_available_url(@options, :eth_call) in @options[:eth_call_urls]

    set_url_unavailable("url_1", :http)
    set_url_unavailable("url_2", :http)

    assert CommonHelper.get_available_url(@options, :http) in @options[:fallback_urls]

    set_url_unavailable("trace_url_1", :trace)
    set_url_unavailable("trace_url_2", :trace)

    assert CommonHelper.get_available_url(@options, :trace) in @options[:fallback_trace_urls]

    set_url_unavailable("eth_call_url_1", :eth_call)
    set_url_unavailable("eth_call_url_2", :eth_call)

    assert CommonHelper.get_available_url(@options, :eth_call) in @options[:fallback_eth_call_urls]
  end

  defp set_url_unavailable(url, url_type) do
    Enum.each(1..3, fn _ ->
      EndpointAvailabilityObserver.inc_error_count(url, [transport_options: @options], url_type)
    end)
  end
end
