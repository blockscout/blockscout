defmodule BlockScoutWeb.API.EthRPC.View do
  @moduledoc """
  Views for /eth-rpc API endpoints
  """
  use BlockScoutWeb, :view

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

  defimpl Poison.Encoder, for: BlockScoutWeb.API.EthRPC.View do
    def encode(%BlockScoutWeb.API.EthRPC.View{result: result, id: id, error: error}, _options) when is_nil(error) do
      result = Poison.encode!(result)

      """
      {"jsonrpc":"2.0","result":#{result},"id":#{id}}
      """
    end

    def encode(%BlockScoutWeb.API.EthRPC.View{id: id, error: error}, _options) do
      """
      {"jsonrpc":"2.0","error": "#{error}","id": #{id}}
      """
    end
  end

  defimpl Jason.Encoder, for: BlockScoutWeb.API.EthRPC.View do
    def encode(%BlockScoutWeb.API.EthRPC.View{result: result, id: id, error: error}, _options) when is_nil(error) do
      result = Jason.encode!(result)

      """
      {"jsonrpc":"2.0","result":#{result},"id":#{id}}
      """
    end

    def encode(%BlockScoutWeb.API.EthRPC.View{id: id, error: error}, _options) do
      """
      {"jsonrpc":"2.0","error": "#{error}","id": #{id}}
      """
    end
  end
end
