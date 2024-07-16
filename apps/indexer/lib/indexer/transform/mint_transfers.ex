defmodule Indexer.Transform.MintTransfers do
  @moduledoc """
  Helper functions to parse addresses from mint transfers.

  When a network receives a mint coin, we can identify it using the `bridge_hash` in the first_topic.
  Then we need to fetch the `from` and `to` address since there is no transaction or internal
  transaction for it. Otherwise, those address may not be indexed.
  """

  @bridge_hash "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a"

  @doc """
  Parses logs to find mint transfers.

  ## Examples

        iex> Indexer.Transform.MintTransfers.parse([
        ...>       %{
        ...>         address_hash: "0x867305d19606aadba405ce534e303d0e225f9556",
        ...>         block_number: 137_194,
        ...>         data: "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
        ...>         first_topic: "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a",
        ...>         fourth_topic: nil,
        ...>         index: 1,
        ...>         second_topic: "0x0000000000000000000000009a4a90e2732f3fa4087b0bb4bf85c76d14833df1",
        ...>         third_topic: "0x0000000000000000000000007301cfa0e1756b71869e93d4e4dca5c7d0eb0aa6",
        ...>         transaction_hash: "0x1d5066d30ff3404a9306733136103ac2b0b989951c38df637f464f3667f8d4ee"
        ...>        }
        ...>     ])
        %{
          mint_transfers: [
            %{
              block_number: 137194,
              from_address_hash: "0x7301cfa0e1756b71869e93d4e4dca5c7d0eb0aa6",
              to_address_hash: "0x9a4a90e2732f3fa4087b0bb4bf85c76d14833df1"
            }
          ]
        }

  """
  def parse(logs) do
    addresses =
      logs
      |> Enum.filter(&(&1.first_topic == @bridge_hash))
      |> Enum.map(&parse_params/1)

    %{mint_transfers: addresses}
  end

  defp parse_params(%{second_topic: second_topic, third_topic: third_topic, block_number: block_number})
       when not is_nil(second_topic) and not is_nil(third_topic) do
    %{
      to_address_hash: truncate_address_hash(second_topic),
      from_address_hash: truncate_address_hash(third_topic),
      block_number: block_number
    }
  end

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end
end
