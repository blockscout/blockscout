# Script to analyze `api/v2/blocks/:block_number/transactions` query behavior.
#
# Usage:
#   DATABASE_URL=postgresql://... BLOCK_NUMBER=10553919 mix run debug_queries.exs

alias Explorer.Chain
alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

require Logger

Logger.configure(level: :warning)

defmodule DebugQueries do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.PagingOptions

  @page_size 50

  def run do
    block_number = System.get_env("BLOCK_NUMBER", "10553919") |> String.to_integer()

    IO.puts(banner("Block transactions preload profiler"))
    IO.puts("DATABASE_URL=#{System.get_env("DATABASE_URL") || "<not set>"}")
    IO.puts("BLOCK_NUMBER=#{block_number}")
    IO.puts("PAGE_SIZE=#{@page_size}")

    case Chain.number_to_block(block_number, api?: true) do
      {:ok, block} ->
        IO.puts("\nBlock found: #{block.number} #{block.hash}")

        profiles = [
          {:full, full_necessity()},
          {:lightweight_smart_contract, lightweight_smart_contract_necessity()},
          {:without_names, without_nested(:names)},
          {:without_smart_contract, without_nested(:smart_contract)},
          {:without_proxy_implementations, without_proxy()},
          {:addresses_only, addresses_only()},
          {:block_only, %{block: :optional}}
        ]

        Enum.each(profiles, fn {label, necessity_by_association} ->
          run_profile(block.hash, label, necessity_by_association)
        end)

      {:error, reason} ->
        IO.puts("\nBlock lookup failed: #{inspect(reason)}")
    end
  end

  defp run_profile(block_hash, label, necessity_by_association) do
    first_run = execute_profile(block_hash, necessity_by_association)
    second_run = execute_profile(block_hash, necessity_by_association)

    IO.puts("\n--- #{label} ---")
    IO.puts("necessity=#{inspect(necessity_by_association, pretty: true, limit: :infinity)}")

    IO.puts(
      "transactions=#{length(second_run.transactions)} elapsed_ms_first=#{format_ms(first_run.elapsed_ms)} elapsed_ms_second=#{format_ms(second_run.elapsed_ms)}"
    )

    IO.puts(
      "queries=#{length(second_run.query_events)} total_sql_ms=#{format_ms(total_query_time_ms(second_run.query_events))}"
    )

    second_run.query_events
    |> Enum.group_by(& &1.source)
    |> Enum.map(fn {source, events} -> {source, length(events), total_query_time_ms(events)} end)
    |> Enum.sort_by(fn {_source, count, total_ms} -> {-total_ms, -count} end)
    |> Enum.each(fn {source, count, total_ms} ->
      IO.puts("  source=#{source} count=#{count} total_ms=#{format_ms(total_ms)}")
    end)

    print_first_transaction_summary(second_run.transactions)
  end

  defp execute_profile(block_hash, necessity_by_association) do
    telemetry_handler = "debug-queries-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      telemetry_handler,
      [
        [:explorer, :repo, :query],
        [:explorer, :repo, :replica1, :query]
      ],
      fn _event, measurements, metadata, pid ->
        send(pid, {:query_event, summarize_query(measurements, metadata)})
      end,
      parent
    )

    {elapsed_us, transactions} =
      :timer.tc(fn ->
        Chain.block_to_transactions(
          block_hash,
          [
            necessity_by_association: necessity_by_association,
            api?: true,
            paging_options: %PagingOptions{page_size: @page_size}
          ],
          false
        )
      end)

    :telemetry.detach(telemetry_handler)

    %{
      elapsed_ms: elapsed_us / 1000,
      transactions: transactions,
      query_events: drain_query_events([])
    }
  end

  defp drain_query_events(acc) do
    receive do
      {:query_event, event} -> drain_query_events([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp summarize_query(measurements, metadata) do
    %{
      source: metadata.source || "<raw>",
      total_ms: System.convert_time_unit(measurements.total_time, :native, :microsecond) / 1000,
      query: metadata.query
    }
  end

  defp total_query_time_ms(events) do
    Enum.reduce(events, 0.0, fn event, acc -> acc + event.total_ms end)
  end

  defp print_first_transaction_summary([]), do: IO.puts("first_tx=<none>")

  defp print_first_transaction_summary([first_tx | _]) do
    IO.puts("first_tx=#{first_tx.hash}")

    IO.puts(
      "  from_address_loaded=#{loaded?(first_tx.from_address)} to_address_loaded=#{loaded?(first_tx.to_address)} created_contract_loaded=#{loaded?(first_tx.created_contract_address)}"
    )

    if loaded?(first_tx.from_address) do
      IO.puts(
        "  from_address names=#{assoc_size(first_tx.from_address.names)} smart_contract=#{loaded?(first_tx.from_address.smart_contract)} proxy_impl=#{loaded?(first_tx.from_address.proxy_implementations)}"
      )
    end
  end

  defp loaded?(value), do: not match?(%Ecto.Association.NotLoaded{}, value) and not is_nil(value)

  defp assoc_size(%Ecto.Association.NotLoaded{}), do: :not_loaded
  defp assoc_size(nil), do: 0
  defp assoc_size(value) when is_list(value), do: length(value)
  defp assoc_size(_value), do: 1

  defp full_necessity do
    %{
      [
        created_contract_address: [
          :scam_badge,
          :names,
          :smart_contract,
          Implementation.proxy_implementations_association()
        ]
      ] => :optional,
      [from_address: [:scam_badge, :names, :smart_contract, Implementation.proxy_implementations_association()]] =>
        :optional,
      [to_address: [:scam_badge, :names, :smart_contract, Implementation.proxy_implementations_association()]] =>
        :optional,
      :block => :optional
    }
  end

  defp lightweight_smart_contract_necessity do
    query =
      from(smart_contract in Explorer.Chain.SmartContract,
        select: struct(smart_contract, [:address_hash])
      )

    %{
      [
        created_contract_address: [
          :scam_badge,
          :names,
          {:smart_contract, query},
          Implementation.proxy_implementations_association()
        ]
      ] => :optional,
      [
        from_address: [
          :scam_badge,
          :names,
          {:smart_contract, query},
          Implementation.proxy_implementations_association()
        ]
      ] => :optional,
      [to_address: [:scam_badge, :names, {:smart_contract, query}, Implementation.proxy_implementations_association()]] =>
        :optional,
      :block => :optional
    }
  end

  defp without_nested(item) do
    full_necessity()
    |> Enum.map(fn
      {[{association, nested}], necessity} when is_list(nested) ->
        {[{association, Enum.reject(nested, &(&1 == item))}], necessity}

      other ->
        other
    end)
    |> Map.new()
  end

  defp without_proxy do
    full_necessity()
    |> Enum.map(fn
      {[{association, nested}], necessity} when is_list(nested) ->
        filtered =
          Enum.reject(nested, fn
            :proxy_implementations -> true
            [proxy_implementations: _nested] -> true
            _ -> false
          end)

        {[{association, filtered}], necessity}

      other ->
        other
    end)
    |> Map.new()
  end

  defp addresses_only do
    %{
      :created_contract_address => :optional,
      :from_address => :optional,
      :to_address => :optional,
      :block => :optional
    }
  end

  defp format_ms(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_ms(value), do: value |> Kernel./(1) |> format_ms()

  defp banner(title) do
    edge = String.duplicate("=", max(String.length(title), 40))
    "#{edge}\n#{title}\n#{edge}"
  end
end

DebugQueries.run()
