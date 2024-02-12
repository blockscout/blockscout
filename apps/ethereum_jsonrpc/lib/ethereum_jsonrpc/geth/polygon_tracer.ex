defmodule EthereumJSONRPC.Geth.PolygonTracer do
  @moduledoc """
  Elixir implementation of a custom tracer (`priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js`)
  for Polygon edge nodes that don't support specifying tracer in [debug_traceTransaction](https://geth.ethereum.org/docs/interacting-with-geth/rpc/ns-debug#debugtracetransaction) calls.
  """

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]

  @burn_address "0x0000000000000000000000000000000000000000"

  def replay(
        %{"structLogs" => logs, "gas" => top_call_gas, "returnValue" => return_value} = result,
        %{"contractAddress" => contract_address},
        %{"from" => from, "to" => to, "value" => value, "input" => input}
      )
      when is_list(logs) do
    top =
      to
      |> if do
        %{
          "type" => "call",
          "callType" => "call",
          "to" => to,
          "input" => input,
          "output" => Map.get(result, "return", "0x" <> Map.get(result, "returnValue", ""))
        }
      else
        %{
          "type" => "create",
          "init" => input,
          "createdContractAddressHash" => contract_address,
          "createdContractCode" => "0x" <> return_value
        }
      end
      |> Map.merge(%{
        "from" => from,
        "traceAddress" => [],
        "value" => value,
        "gas" => 0,
        "gasUsed" => 0
      })

    ctx = %{
      depth: 1,
      stack: [top],
      trace_address: [0],
      calls: [[]],
      descended: false
    }

    logs
    |> Enum.reduce(ctx, &step/2)
    |> finalize(top_call_gas)
  end

  defp step(%{"error" => _}, %{stack: [%{"error" => _} | _]} = ctx), do: ctx

  defp step(
         %{"error" => _} = log,
         %{
           depth: stack_depth,
           stack: [call | stack],
           trace_address: [_, trace_index | trace_address],
           calls: [subsubcalls, subcalls | calls]
         } = ctx
       ) do
    call = process_return(log, Map.put(call, "error", "error"))

    subsubcalls =
      subsubcalls
      |> Stream.map(fn
        subcalls when is_list(subcalls) -> subcalls
        subcall when is_map(subcall) -> %{subcall | "from" => call["createdContractAddressHash"] || call["to"]}
      end)
      |> Enum.reverse()

    %{
      ctx
      | depth: stack_depth - 1,
        stack: stack,
        trace_address: [trace_index + 1 | trace_address],
        calls: [[subsubcalls, call | subcalls] | calls]
    }
  end

  defp step(
         %{"gas" => log_gas} = log,
         %{
           stack: [%{"gas" => call_gas} = call | stack],
           descended: true
         } = ctx
       ) do
    gas = max(call_gas, log_gas)
    call = %{call | "gas" => gas}
    step(log, %{ctx | stack: [call | stack], descended: false})
  end

  defp step(
         %{"depth" => log_depth} = log,
         %{
           depth: stack_depth,
           stack: [call | stack],
           trace_address: [_, trace_index | trace_address],
           calls: [subsubcalls, subcalls | calls]
         } = ctx
       )
       when log_depth == stack_depth - 1 do
    call = process_return(log, call)

    subsubcalls =
      subsubcalls
      |> Stream.map(fn
        subcalls when is_list(subcalls) -> subcalls
        subcall when is_map(subcall) -> %{subcall | "from" => call["createdContractAddressHash"] || call["to"]}
      end)
      |> Enum.reverse()

    step(log, %{
      ctx
      | depth: stack_depth - 1,
        stack: stack,
        trace_address: [trace_index + 1 | trace_address],
        calls: [[subsubcalls, call | subcalls] | calls]
    })
  end

  defp step(%{"gas" => log_gas, "gasCost" => log_gas_cost} = log, %{stack: [%{"gas" => call_gas} = call | stack]} = ctx) do
    gas = max(call_gas, log_gas)
    op(log, %{ctx | stack: [%{call | "gas" => gas, "gasUsed" => gas - log_gas - log_gas_cost} | stack]})
  end

  defp op(%{"op" => "CREATE"} = log, ctx), do: create_op(log, ctx)
  defp op(%{"op" => "CREATE2"} = log, ctx), do: create_op(log, ctx, "create2")
  defp op(%{"op" => "SELFDESTRUCT"} = log, ctx), do: self_destruct_op(log, ctx)
  defp op(%{"op" => "CALL"} = log, ctx), do: call_op(log, "call", ctx)
  defp op(%{"op" => "CALLCODE"} = log, ctx), do: call_op(log, "callcode", ctx)
  defp op(%{"op" => "DELEGATECALL"} = log, ctx), do: call_op(log, "delegatecall", ctx)
  defp op(%{"op" => "STATICCALL"} = log, ctx), do: call_op(log, "staticcall", ctx)
  defp op(%{"op" => "REVERT"}, ctx), do: revert_op(ctx)
  defp op(_, ctx), do: ctx

  defp process_return(
         %{"stack" => log_stack},
         %{"type" => create} = call
       )
       when create in ~w(create create2) do
    [ret | _] = Enum.reverse(log_stack)

    ret
    |> quantity_to_integer()
    |> case do
      0 ->
        Map.put(call, "error", call["error"] || "internal failure")

      _ ->
        %{call | "createdContractAddressHash" => ret}
    end
  end

  defp process_return(
         %{"stack" => log_stack, "memory" => log_memory},
         %{"outputOffset" => out_off, "outputLength" => out_len} = call
       ) do
    [ret | _] = Enum.reverse(log_stack)

    ret
    |> quantity_to_integer()
    |> case do
      0 ->
        Map.put(call, "error", call["error"] || "internal failure")

      _ ->
        output =
          log_memory
          |> IO.iodata_to_binary()
          |> String.slice(out_off, out_len)

        %{call | "output" => "0x" <> output}
    end
    |> Map.drop(["outputOffset", "outputLength"])
  end

  defp process_return(_log, call) do
    call
  end

  defp create_op(
         %{"stack" => log_stack, "memory" => log_memory},
         %{depth: stack_depth, stack: stack, trace_address: trace_address, calls: calls} = ctx,
         type \\ "create"
       ) do
    [value, input_length | _] = Enum.reverse(log_stack)

    init =
      log_memory
      |> IO.iodata_to_binary()
      |> String.slice(0, quantity_to_integer(input_length) * 2)

    call = %{
      "type" => type,
      "from" => nil,
      "traceAddress" => Enum.reverse(trace_address),
      "init" => "0x" <> init,
      "gas" => 0,
      "gasUsed" => 0,
      "value" => value,
      "createdContractAddressHash" => nil,
      "createdContractCode" => "0x"
    }

    %{
      ctx
      | depth: stack_depth + 1,
        stack: [call | stack],
        trace_address: [0 | trace_address],
        calls: [[] | calls],
        descended: true
    }
  end

  defp self_destruct_op(
         %{"stack" => log_stack, "gas" => log_gas, "gasCost" => log_gas_cost},
         %{trace_address: [trace_index | trace_address], calls: [subcalls | calls]} = ctx
       ) do
    [to | _] = Enum.reverse(log_stack)

    if quantity_to_integer(to) in 1..8 do
      ctx
    else
      call = %{
        "type" => "selfdestruct",
        "from" => nil,
        "to" => to,
        "traceAddress" => Enum.reverse([trace_index | trace_address]),
        "gas" => log_gas,
        "gasUsed" => log_gas_cost,
        "value" => "0x0"
      }

      %{ctx | trace_address: [trace_index + 1 | trace_address], calls: [[call | subcalls] | calls]}
    end
  end

  defp call_op(
         %{"stack" => call_stack},
         call_type,
         %{
           depth: stack_depth,
           stack: stack,
           trace_address: trace_address,
           calls: calls
         } = ctx
       )
       when length(call_stack) < 3 do
    call = %{
      "type" => "call",
      "callType" => call_type,
      "from" => nil,
      "to" => @burn_address,
      "traceAddress" => Enum.reverse(trace_address),
      "input" => "0x",
      "output" => "0x",
      "outputOffset" => 0,
      "outputLength" => 0,
      "gas" => 0,
      "gasUsed" => 0,
      "value" => "0x0"
    }

    %{
      ctx
      | depth: stack_depth + 1,
        stack: [call | stack],
        trace_address: [0 | trace_address],
        calls: [[] | calls],
        descended: true
    }
  end

  defp call_op(
         %{"stack" => log_stack, "memory" => log_memory},
         call_type,
         %{
           depth: stack_depth,
           stack: [%{"value" => parent_value} = parent | stack],
           trace_address: trace_address,
           calls: calls
         } = ctx
       ) do
    [_, to | log_stack] = Enum.reverse(log_stack)

    {value, [input_length, output_length | _]} =
      case call_type do
        "delegatecall" ->
          {parent_value, log_stack}

        "staticcall" ->
          {"0x0", log_stack}

        _ ->
          [value | rest] = log_stack
          {value, rest}
      end

    input =
      log_memory
      |> IO.iodata_to_binary()
      |> String.slice(0, quantity_to_integer(input_length || 0) * 2)

    call = %{
      "type" => "call",
      "callType" => call_type,
      "from" => nil,
      "to" => to,
      "traceAddress" => Enum.reverse(trace_address),
      "input" => "0x" <> input,
      "output" => "0x",
      "outputOffset" => quantity_to_integer(input_length) * 2,
      "outputLength" => quantity_to_integer(output_length) * 2,
      "gas" => 0,
      "gasUsed" => 0,
      "value" => value
    }

    %{
      ctx
      | depth: stack_depth + 1,
        stack: [call, parent | stack],
        trace_address: [0 | trace_address],
        calls: [[] | calls],
        descended: true
    }
  end

  defp revert_op(%{stack: [last | stack]} = ctx) do
    %{ctx | stack: [Map.put(last, "error", "execution reverted") | stack]}
  end

  defp finalize(%{stack: [top], calls: [calls]}, top_call_gas) do
    calls =
      Enum.map(calls, fn
        subcalls when is_list(subcalls) ->
          subcalls

        subcall when is_map(subcall) ->
          %{subcall | "from" => top["createdContractAddressHash"] || top["to"]}
      end)

    [%{top | "gasUsed" => top_call_gas} | Enum.reverse(calls)]
    |> List.flatten()
    |> Enum.map(fn %{"gas" => gas, "gasUsed" => gas_used} = call ->
      %{call | "gas" => integer_to_quantity(gas), "gasUsed" => gas_used |> max(0) |> integer_to_quantity()}
    end)
  end
end
