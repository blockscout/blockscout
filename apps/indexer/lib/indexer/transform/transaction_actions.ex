defmodule Indexer.Transform.TransactionActions do
  @moduledoc """
  Helper functions for transforming data for transaction actions.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias ABI.TypeDecoder
  alias Explorer.Chain.Cache.NetVersion
  alias Explorer.Chain.TransactionActions
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever

  @mainnet 1
  @optimism 10
  @polygon 137
  @gnosis 100

  @uniswap_v3_positions_nft "0xc36442b4a4522e871399cd717abdd847ab11fe88"

  @doc """
  Returns a list of transaction actions given a list of logs.
  """
  def parse(logs) do
    actions = []

    chain_id = NetVersion.get_version()

    logs
    |> logs_group_by_txs()
    |> clear_actions()

    actions =
      if Enum.member?([@mainnet, @optimism, @polygon], chain_id) do
        logs
        |> Enum.filter(fn log ->
          first_topic = String.downcase(log.first_topic)

          Enum.member?(
            [
              "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde",
              "0x0c396cd989a39f4459b5fa1aed6a9a8dcdbc45908acfd67e028cd568da98982c",
              "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0",
              "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
            ],
            first_topic
          ) ||
            (first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" &&
               String.downcase(log.address_hash) == @uniswap_v3_positions_nft)
        end)
        |> logs_group_by_txs()
        |> uniswap(actions)
      else
        actions
      end

    %{transaction_actions: actions}
  end

  defp uniswap(logs_grouped, actions) do
    # iterate for each transaction
    Enum.reduce(logs_grouped, actions, fn {tx_hash, tx_logs}, actions_acc ->
      # iterate for all logs of the transaction
      mint_nft_ids =
        Enum.reduce(tx_logs, %{}, fn log, acc ->
          first_topic = String.downcase(log.first_topic)

          if first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
            # This is Transfer event for NFT
            from = truncate_address_hash(log.second_topic)

            if from == "0x0000000000000000000000000000000000000000" do
              to = truncate_address_hash(log.third_topic)
              [tokenId] = decode_data(log.fourth_topic, [{:uint, 256}])

              mint_nft_ids =
                if not Map.has_key?(acc, to) do
                  Map.put(acc, to, [])
                else
                  acc
                end

              Map.put(mint_nft_ids, to, mint_nft_ids[to] ++ [to_string(tokenId)])
            else
              acc
            end
          else
            acc
          end
        end)

      new_actions_acc =
        actions_acc ++
          Enum.map(mint_nft_ids, fn {to, ids} ->
            %{
              hash: tx_hash,
              protocol: "uniswap_v3",
              data: %{
                name: "Uniswap V3: Positions NFT",
                symbol: "UNI-V3-POS",
                address: @uniswap_v3_positions_nft,
                to: to,
                ids: ids
              },
              type: "mint_nft"
            }
          end)

      new_actions_acc
    end)
  end

  defp clear_actions(logs_grouped) do
    logs_grouped
    |> Enum.each(fn {tx_hash, _} ->
      from(ta in TransactionActions, where: ta.hash == ^tx_hash) |> Repo.delete_all
    end)
  end

  defp decode_data("0x", types) do
    for _ <- types, do: nil
  end

  defp decode_data("0x" <> encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  # defp encode_address_hash(binary) do
  #   "0x" <> Base.encode16(binary, case: :lower)
  # end

  defp logs_group_by_txs(logs) do
    logs
    |> Enum.reduce(%{}, fn log, acc ->
      acc =
        if not Map.has_key?(acc, log.transaction_hash) do
          Map.put(acc, log.transaction_hash, [])
        else
          acc
        end

      Map.put(acc, log.transaction_hash, acc[log.transaction_hash] ++ [log])
    end)
  end

  defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end
end
