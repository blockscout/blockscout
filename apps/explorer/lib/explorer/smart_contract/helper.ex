defmodule Explorer.SmartContract.Helper do
  @moduledoc """
  SmartContract helper functions
  """

  def queriable_method?(method) do
    method["constant"] || method["stateMutability"] == "view" || method["stateMutability"] == "pure"
  end

  def constructor?(function), do: function["type"] == "constructor"

  def event?(function), do: function["type"] == "event"

  def error?(function), do: function["type"] == "error"

  @doc """
    Checks whether the function which is not queriable can be consider as read function or not. 
  """
  @spec read_with_wallet_method?(%{}) :: true | false
  def read_with_wallet_method?(function),
    do:
      !error?(function) && !event?(function) && !constructor?(function) && nonpayable?(function) &&
        !empty_outputs?(function)

  def empty_inputs?(function), do: function["inputs"] == []

  def empty_outputs?(function), do: function["outputs"] == []

  def payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  def nonpayable?(function) do
    if function["type"] do
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
    else
      false
    end
  end

  def event_abi_to_topic_str(%{"type" => "event", "name" => name} = event) do
    types =
      event
      |> Map.get("inputs", [])
      |> Enum.map(& &1["type"])
      |> Enum.join(",")

    function_signature = "#{name}(#{types})"

    topic =
      function_signature
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    "0x" <> topic
  end
end
