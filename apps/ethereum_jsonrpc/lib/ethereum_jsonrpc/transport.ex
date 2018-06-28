defmodule EthereumJSONRPC.Transport do
  @moduledoc """
  The transport over which JSONRPC calls occur.

  Various clients support the transports below:

   * HTTP
   * IPC
   * WS

  """

  @typedoc @moduledoc
  @type t :: module

  @typedoc """
  The name of the JSONRPC method
  """
  @type method :: String.t()

  @typedoc """
  [JSONRPC request object](https://www.jsonrpc.org/specification#request_object)

   * `:jsonrpc` - a `t:String.t/0` specifying the JSONR-RPC protocol version.  MUST be exactly `"2.0"`
   * `:method` - a `t:String.t/0` containing the name of the method to be invoked.
   * `:params` - a `t:list/0` for the positional parameters for the `"method"`.
   * `:id` - a `non_neg_integer` that is unique for in a `t:batch_request/0`.

  """
  @type request :: %{jsonrpc: String.t(), method: method, params: list(), id: non_neg_integer()}

  @typedoc """
  A batch of `t:request/0`.  Each `t:request/0` in the batch must have a unique `"id"`.
  """
  @type batch_request :: [request]

  @type result :: term()

  @typedoc """
  [JSONRPC response object](https://www.jsonrpc.org/specification#response_object)

  ## Result

   * `:jsonrpc` - a `t:String.t/0` specifying the JSONR-RPC protocol version.  MUST be exactly `"2.0"`
   * `:result` - the successful result of the request
   * `:id` - the `"id'` of the `t:request/0` that correlates with this response

  ## Error

   * `:jsonrpc` - a `t:String.t/0` specifying the JSONR-RPC protocol version.  MUST be exactly `"2.0"`
   * `:error:` - the `t:error/0`
   * `:id` - the `"id'` of the `t:request/0` that correlates with this response

  """
  @type response ::
          %{jsonrpc: String.t(), result: result, id: non_neg_integer()}
          | %{jsonrpc: String.t(), error: error, id: non_neg_integer()}

  @typedoc """
  [JSONRPC error object](https://www.jsonrpc.org/specification#error_object)

   * `:code` - an `t:integer/0` indicating the error type
   * `:message` -
  """
  @type error :: %{required(:code) => integer(), required(:message) => String.t(), optional(:data) => term()}

  @typedoc """
  A batch of `t:response/0`.  Each `t:response/0` will have an `"id"` corresponding to the `"id"` in the `t:request/0`.
  """
  @type batch_response :: [response]

  @typedoc """
  Transport-specific options
  """
  @type options :: term()

  @callback json_rpc(request, options) :: {:ok, result} | {:error, reason :: term()}
  @callback json_rpc(batch_request, options) :: {:ok, batch_response} | {:error, reason :: term()}
end
