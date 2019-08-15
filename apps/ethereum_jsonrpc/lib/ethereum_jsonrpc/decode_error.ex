defmodule EthereumJSONRPC.DecodeError do
  @moduledoc """
  An error has occurred decoding the response to an `EthereumJSONRPC.json_rpc` request.
  """

  @enforce_keys [:request, :response]
  defexception [:request, :response]

  defmodule Request do
    @moduledoc """
    Ethereum JSONRPC request whose `EthereumJSONRPC.DecodeError.Response` had a decode error.
    """

    @enforce_keys [:url, :body]
    defstruct [:url, :body]
  end

  defmodule Response do
    @moduledoc """
    Ethereum JSONRPC response that had a decode error.
    """

    @enforce_keys [:status_code, :body]
    defstruct [:status_code, :body]
  end

  @impl Exception
  def exception(named_arguments) do
    request_fields = Keyword.fetch!(named_arguments, :request)
    request = struct!(EthereumJSONRPC.DecodeError.Request, request_fields)

    response_fields = Keyword.fetch!(named_arguments, :response)
    response = struct!(EthereumJSONRPC.DecodeError.Response, response_fields)

    %EthereumJSONRPC.DecodeError{request: request, response: response}
  end

  @request_body_limit 700

  @impl Exception
  def message(%EthereumJSONRPC.DecodeError{
        request: %EthereumJSONRPC.DecodeError.Request{url: request_url, body: request_body},
        response: %EthereumJSONRPC.DecodeError.Response{status_code: response_status_code, body: response_body}
      }) do
    request_body_binary = IO.iodata_to_binary(request_body)

    truncated_request_body =
      if byte_size(request_body_binary) < @request_body_limit do
        request_body_binary
      else
        <<result::binary-size(@request_body_limit), _::binary>> = request_body_binary
        result
      end

    """
    Failed to decode Ethereum JSONRPC response:

      request:

        url: #{request_url}

        body: #{truncated_request_body}

      response:

        status code: #{response_status_code}

        body: #{response_body}
    """
  end
end
