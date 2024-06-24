defmodule BlockScoutWeb.API.V2.CeloView do
  require Logger

  import Explorer.Chain.Celo.Helper, only: [is_epoch_block_number: 1]

  alias Ecto.Association.NotLoaded

  alias BlockScoutWeb.API.V2.{TokenView, TransactionView, Helper}
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Celo.Helper, as: CeloHelper
  alias Explorer.Chain.Celo.EpochReward
  alias Explorer.Chain.Cache.CeloCoreContracts

  def render("celo_epoch_rewards.json", block) when is_epoch_block_number(block.number) do
    %EpochReward{
      reserve_bolster_transfer: reserve_bolster_transfer,
      community_transfer: community_transfer,
      carbon_offsetting_transfer: carbon_offsetting_transfer
    } = EpochReward.load_token_transfers(block.celo_epoch_reward)

    Map.new(
      [
        reserve_bolster_transfer: reserve_bolster_transfer,
        community_transfer: community_transfer,
        carbon_offsetting_transfer: carbon_offsetting_transfer
      ],
      fn {field, token_transfer} ->
        token_transfer_json =
          token_transfer &&
            TransactionView.render(
              "token_transfer.json",
              %{token_transfer: token_transfer, conn: nil}
            )

        {field, token_transfer_json}
      end
    )
  end

  def render("celo_epoch_rewards.json", _block), do: nil

  def render("celo_base_fee.json", %Block{} = block) do
    # For the blocks, where both FeeHandler and Governance contracts aren't
    # deployed, the base fee is not burnt, but refunded to transaction sender,
    # so we return nil in this case.

    base_fee = Block.burnt_fees(block.transactions, block.base_fee_per_gas)

    fee_handler_base_fee_breakdown(
      base_fee,
      block.number
    ) ||
      governance_base_fee_breakdown(
        base_fee,
        block.number
      )
  end

  defp burn_fraction_decimal(burn_fraction_fixidity_lib)
       when is_integer(burn_fraction_fixidity_lib) do
    base = Decimal.new(1, 10, 24)
    fraction = Decimal.new(1, burn_fraction_fixidity_lib, 0)
    Decimal.div(fraction, base)
  end

  defp fee_handler_base_fee_breakdown(base_fee, block_number) do
    with {:ok, fee_handler_contract_address_hash} when not is_nil(fee_handler_contract_address_hash) <-
           CeloCoreContracts.get_address(:fee_handler, block_number),
         {:ok, %{"address" => fee_beneficiary_address_hash}} <-
           CeloCoreContracts.get_event(:fee_handler, :fee_beneficiary_set, block_number),
         {:ok, %{"value" => burn_fraction_fixidity_lib}} <-
           CeloCoreContracts.get_event(:fee_handler, :burn_fraction_set, block_number) do
      burn_fraction = burn_fraction_decimal(burn_fraction_fixidity_lib)

      burnt_amount = Decimal.mult(base_fee, burn_fraction)
      burnt_percentage = Decimal.mult(burn_fraction, 100)

      carbon_offsetting_amount = Decimal.sub(base_fee, burnt_amount)
      carbon_offsetting_percentage = Decimal.sub(100, burnt_percentage)

      address_hashes_to_fetch_from_db = [
        fee_handler_contract_address_hash,
        fee_beneficiary_address_hash,
        CeloHelper.burn_address_hash_string()
      ]

      [
        fee_handler_contract_address_info,
        fee_beneficiary_address_info,
        burn_address_info
      ] =
        address_hashes_to_fetch_from_db
        |> Enum.map(&(&1 |> Chain.string_to_address_hash() |> elem(1)))
        |> Chain.hashes_to_addresses()
        |> Stream.concat(Stream.duplicate(nil, 3))
        |> Stream.zip(address_hashes_to_fetch_from_db)
        |> Enum.map(fn {address, address_hash} ->
          Helper.address_with_info(
            address,
            address_hash
          )
        end)

      %{
        recipient: fee_handler_contract_address_info,
        amount: base_fee,
        breakdown: [
          %{
            address: burn_address_info,
            amount: Decimal.to_float(burnt_amount),
            percentage: Decimal.to_float(burnt_percentage)
          },
          %{
            address: fee_beneficiary_address_info,
            amount: Decimal.to_float(carbon_offsetting_amount),
            percentage: Decimal.to_float(carbon_offsetting_percentage)
          }
        ]
      }
    else
      _ -> nil
    end
  end

  defp governance_base_fee_breakdown(base_fee, block_number) do
    with {:ok, address_hash_string} when not is_nil(address_hash_string) <-
           CeloCoreContracts.get_address(:governance, block_number),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      address =
        address_hash
        |> Chain.hash_to_address()
        |> case do
          {:ok, address} -> address
          {:error, :not_found} -> nil
        end

      address_with_info =
        Helper.address_with_info(
          address,
          address_hash
        )

      %{
        recipient: address_with_info,
        amount: base_fee,
        breakdown: []
      }
    else
      _ ->
        nil
    end
  end

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    token_json =
      case {
        Map.get(transaction, :gas_token_contract_address),
        Map.get(transaction, :gas_token)
      } do
        # todo: this clause is redundant, consider removing it
        {_, %NotLoaded{}} ->
          nil

        {nil, _} ->
          nil

        {gas_token_contract_address, gas_token} ->
          if is_nil(gas_token) do
            Logger.error(fn ->
              [
                "Transaction #{transaction.hash} has a ",
                "gas token contract address #{gas_token_contract_address} ",
                "but no associated token found in the database"
              ]
            end)
          end

          TokenView.render("token.json", %{
            token: gas_token,
            contract_address_hash: gas_token_contract_address
          })
      end

    Map.put(out_json, "celo", %{"gas_token" => token_json})
  end

  defp maybe_add_epoch_rewards(celo_epoch_json, block, true) do
    epoch_rewards_json = render("celo_epoch_rewards.json", block)
    Map.put(celo_epoch_json, "rewards", epoch_rewards_json)
  end

  defp maybe_add_epoch_rewards(celo_epoch_json, _block, false),
    do: celo_epoch_json

  defp maybe_add_base_fee(celo_json, block_or_transaction, true) do
    base_fee_breakdown_json = render("celo_base_fee.json", block_or_transaction)
    Map.put(celo_json, "base_fee", base_fee_breakdown_json)
  end

  defp maybe_add_base_fee(celo_json, _block_or_transaction, false),
    do: celo_json

  def extend_block_json_response(out_json, %Block{} = block, single_block?) do
    celo_epoch_json =
      %{
        "is_epoch_block" => CeloHelper.epoch_block_number?(block.number),
        "number" => CeloHelper.block_number_to_epoch_number(block.number)
      }
      |> maybe_add_epoch_rewards(block, single_block?)

    celo_json =
      %{"epoch" => celo_epoch_json}
      |> maybe_add_base_fee(block, single_block?)

    Map.put(out_json, "celo", celo_json)
  end
end
