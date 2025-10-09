defmodule BlockScoutWeb.API.EthRPC.View do
  @moduledoc """
  Views for /eth-rpc API endpoints
  """
  use BlockScoutWeb, :view

  @jsonrpc_2_0 ~s("jsonrpc":"2.0")

  defstruct [:result, :id, :error]

  def render("show.json", %{result: result, id: id}) do
    %__MODULE__{
      result: result,
      id: id
    }
  end

  def render("error.json", %{error: message, id: id}) do
    %__MODULE__{
      error: message,
      id: id
    }
  end

  def render("response.json", %{response: %{error: error, id: id}}) do
    %__MODULE__{
      error: error,
      id: id
    }
  end

  def render("response.json", %{response: %{result: result, id: id}}) do
    %__MODULE__{
      result: result,
      id: id
    }
  end

  def render("responses.json", %{responses: responses}) do
    Enum.map(responses, fn
      %{error: error, id: id} ->
        %__MODULE__{
          error: error,
          id: id
        }

      %{result: result, id: id} ->
        %__MODULE__{
          result: result,
          id: id
        }
    end)
  end

  @doc """
  Encodes id into JSON string
  """
  @spec sanitize_id(any()) :: non_neg_integer() | String.t()
  def sanitize_id(id) do
    if is_integer(id), do: id, else: "\"#{id}\""
  end

  @doc """
  Encodes error into JSON string
  """
  @spec sanitize_error(any(), :jason | :poison) :: String.t()
  def sanitize_error(error, json_encoder) do
    case json_encoder do
      :jason -> if is_map(error), do: Jason.encode!(error), else: "\"#{error}\""
      :poison -> if is_map(error), do: Poison.encode!(error), else: "\"#{error}\""
    end
  end

  @doc """
  Pass "jsonrpc":"2.0" to use in Poison.Encoder and Jason.Encoder below
  """
  @spec jsonrpc_2_0() :: String.t()
  def jsonrpc_2_0, do: @jsonrpc_2_0

  defimpl Poison.Encoder, for: BlockScoutWeb.API.EthRPC.View do
    alias BlockScoutWeb.API.EthRPC.View

    def encode(%View{result: result, id: id, error: error}, _options) when is_nil(error) do
      result = Poison.encode!(result)

      """
      {#{View.jsonrpc_2_0()},"result": #{result},"id": #{View.sanitize_id(id)}}
      """
    end

    def encode(%View{id: id, error: error}, _options) do
      """
      {#{View.jsonrpc_2_0()},"error": #{View.sanitize_error(error, :poison)},"id": #{View.sanitize_id(id)}}
      """
    end
  end

  defimpl Jason.Encoder, for: BlockScoutWeb.API.EthRPC.View do
    # credo:disable-for-next-line
    alias BlockScoutWeb.API.EthRPC.View

    def encode(%View{result: result, id: id, error: error}, _options) when is_nil(error) do
      result = Jason.encode!(result)

      """
      {#{View.jsonrpc_2_0()},"result": #{result},"id": #{View.sanitize_id(id)}}
      """
    end

    def encode(%View{id: id, error: error}, _options) do
      """
      {#{View.jsonrpc_2_0()},"error": #{View.sanitize_error(error, :jason)},"id": #{View.sanitize_id(id)}}
      """
    end
  end
end
