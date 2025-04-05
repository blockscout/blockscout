defmodule BlockScoutWeb.API.V2.CeloView do
  @moduledoc """
  View functions for rendering Celo-related data in JSON format.
  """
  use BlockScoutWeb, :view

  require Logger

  import Explorer.Chain.SmartContract, only: [dead_address_hash_string: 0]

  alias BlockScoutWeb.API.V2.{Helper, TokenView, TransactionView}
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.Helper, as: CeloHelper
  alias Explorer.Chain.Celo.{ElectionReward, EpochReward}
  alias Explorer.Chain.Hash
  alias Explorer.Chain.{Block, Token, Transaction, Wei}

  @address_params [
    necessity_by_association: %{
      :names => :optional,
      :smart_contract => :optional,
      proxy_implementations_association() => :optional
    },
    api?: true
  ]

  def render("celo_epoch.json", %{epoch_number: epoch_number, epoch_distribution: nil}) do
    %{
      number: epoch_number,
      distribution: nil,
      aggregated_election_rewards: nil
    }
  end

  def render(
        "celo_epoch.json",
        %{
          epoch_number: epoch_number,
          epoch_distribution: %EpochReward{
            reserve_bolster_transfer: reserve_bolster_transfer,
            community_transfer: community_transfer,
            carbon_offsetting_transfer: carbon_offsetting_transfer
          },
          aggregated_election_rewards: aggregated_election_rewards
        }
      ) do
    distribution_json =
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

    aggregated_election_rewards_json =
      Map.new(
        aggregated_election_rewards,
        fn {type, %{total: total, count: count, token: token}} ->
          {type,
           %{
             total: total,
             count: count,
             token:
               TokenView.render("token.json", %{
                 token: token,
                 contract_address_hash: token && token.contract_address_hash
               })
           }}
        end
      )

    %{
      number: epoch_number,
      distribution: distribution_json,
      aggregated_election_rewards: aggregated_election_rewards_json
    }
  end

  def render("celo_base_fee.json", %Block{} = block) do
    block.transactions
    |> Block.burnt_fees(block.base_fee_per_gas)
    |> Wei.cast()
    |> case do
      {:ok, base_fee} ->
        # For the blocks, where both FeeHandler and Governance contracts aren't
        # deployed, the base fee is not burnt, but refunded to transaction sender,
        # so we return nil in this case.
        fee_handler_base_fee_breakdown(
          base_fee,
          block.number
        ) ||
          governance_base_fee_breakdown(
            base_fee,
            block.number
          )

      _ ->
        nil
    end
  end

  def render("celo_election_rewards.json", %{
        rewards: rewards,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(rewards, &prepare_election_reward/1),
      "next_page_params" => next_page_params
    }
  end

  @doc """
  Extends the JSON output with a sub-map containing information related to Celo,
  such as the epoch number, whether the block is an epoch block, and the routing
  of the base fee.

  ## Parameters
  - `out_json`: A map defining the output JSON which will be extended.
  - `block`: The block structure containing Celo-related data.
  - `single_block?`: A boolean indicating if it is a single block.

  ## Returns
  - A map extended with data related to Celo.
  """
  def extend_block_json_response(out_json, %Block{} = block, single_block?) do
    celo_json =
      %{
        "is_epoch_block" => CeloHelper.epoch_block_number?(block.number),
        "epoch_number" => CeloHelper.block_number_to_epoch_number(block.number)
      }
      |> maybe_add_base_fee_info(block, single_block?)

    Map.put(out_json, "celo", celo_json)
  end

  @doc """
  Extends the JSON output with a sub-map containing information about the gas
  token used to pay for the transaction fees.

  ## Parameters
  - `out_json`: A map defining the output JSON which will be extended.
  - `transaction`: The transaction structure containing Celo-related data.

  ## Returns
  - A map extended with data related to the gas token.
  """
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    token_json =
      case {
        Map.get(transaction, :gas_token_contract_address),
        Map.get(transaction, :gas_token)
      } do
        # {_, %NotLoaded{}} ->
        #   nil

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

  @spec prepare_election_reward(Explorer.Chain.Celo.ElectionReward.t()) :: %{
          :account => nil | %{optional(String.t()) => any()},
          :amount => Decimal.t(),
          :associated_account => nil | %{optional(String.t()) => any()},
          optional(:block_hash) => Hash.Full.t(),
          optional(:block_number) => Block.block_number(),
          optional(:epoch_number) => non_neg_integer(),
          optional(:type) => ElectionReward.type()
        }
  defp prepare_election_reward(%ElectionReward{block: %NotLoaded{}} = reward) do
    %{
      amount: reward.amount,
      account:
        Helper.address_with_info(
          reward.account_address,
          reward.account_address_hash
        ),
      associated_account:
        Helper.address_with_info(
          reward.associated_account_address,
          reward.associated_account_address_hash
        )
    }
  end

  defp prepare_election_reward(%ElectionReward{token: %Token{}, block: %Block{}} = reward) do
    %{
      amount: reward.amount,
      block_number: reward.block.number,
      block_hash: reward.block_hash,
      block_timestamp: reward.block.timestamp,
      epoch_number: reward.block.number |> CeloHelper.block_number_to_epoch_number(),
      account:
        Helper.address_with_info(
          reward.account_address,
          reward.account_address_hash
        ),
      associated_account:
        Helper.address_with_info(
          reward.associated_account_address,
          reward.associated_account_address_hash
        ),
      type: reward.type,
      token:
        TokenView.render("token.json", %{
          token: reward.token,
          contract_address_hash: reward.token.contract_address_hash
        })
    }
  end

  # Get the breakdown of the base fee for the case when FeeHandler is a contract
  # that receives the base fee.
  @spec fee_handler_base_fee_breakdown(Wei.t(), Block.block_number()) ::
          %{
            :recipient => %{optional(String.t()) => any()},
            :amount => float(),
            :breakdown => [
              %{
                :address => %{optional(String.t()) => any()},
                :amount => float(),
                :percentage => float()
              }
            ]
          }
          | nil
  defp fee_handler_base_fee_breakdown(base_fee, block_number) do
    with {:ok, fee_handler_contract_address_hash} <-
           CeloCoreContracts.get_address(:fee_handler, block_number),
         {:ok, %{"address" => fee_beneficiary_address_hash}} <-
           CeloCoreContracts.get_event(:fee_handler, :fee_beneficiary_set, block_number),
         {:ok, %{"value" => burn_fraction_fixidity_lib}} <-
           CeloCoreContracts.get_event(:fee_handler, :burn_fraction_set, block_number),
         {:ok, celo_token_address_hash} <- CeloCoreContracts.get_address(:celo_token, block_number) do
      burn_fraction = CeloHelper.burn_fraction_decimal(burn_fraction_fixidity_lib)

      burnt_amount = Wei.mult(base_fee, burn_fraction)
      burnt_percentage = Decimal.mult(burn_fraction, 100)

      carbon_offsetting_amount = Wei.sub(base_fee, burnt_amount)
      carbon_offsetting_percentage = Decimal.sub(100, burnt_percentage)

      celo_burn_address_hash_string = dead_address_hash_string()

      address_hashes_to_fetch_from_db = [
        fee_handler_contract_address_hash,
        fee_beneficiary_address_hash,
        celo_burn_address_hash_string
      ]

      address_hash_string_to_address =
        address_hashes_to_fetch_from_db
        |> Enum.map(&(&1 |> Chain.string_to_address_hash() |> elem(1)))
        # todo: Querying database in the view is not a good practice. Consider
        # refactoring.
        |> Chain.hashes_to_addresses(@address_params)
        |> Map.new(fn address ->
          {
            to_string(address.hash),
            address
          }
        end)

      %{
        ^fee_handler_contract_address_hash => fee_handler_contract_address_info,
        ^fee_beneficiary_address_hash => fee_beneficiary_address_info,
        ^celo_burn_address_hash_string => burn_address_info
      } =
        Map.new(
          address_hashes_to_fetch_from_db,
          &{
            &1,
            Helper.address_with_info(
              Map.get(address_hash_string_to_address, &1),
              &1
            )
          }
        )

      celo_token = Token.get_by_contract_address_hash(celo_token_address_hash, api?: true)

      %{
        recipient: fee_handler_contract_address_info,
        amount: base_fee,
        token:
          TokenView.render("token.json", %{
            token: celo_token,
            contract_address_hash: celo_token.contract_address_hash
          }),
        breakdown: [
          %{
            address: burn_address_info,
            amount: burnt_amount,
            percentage: Decimal.to_float(burnt_percentage)
          },
          %{
            address: fee_beneficiary_address_info,
            amount: carbon_offsetting_amount,
            percentage: Decimal.to_float(carbon_offsetting_percentage)
          }
        ]
      }
    else
      _ -> nil
    end
  end

  # Get the breakdown of the base fee for the case when Governance is a contract
  # that receives the base fee.
  #
  # Note that the base fee is not burnt in this case, but simply kept on the
  # contract balance.
  @spec governance_base_fee_breakdown(Wei.t(), Block.block_number()) ::
          %{
            :recipient => %{optional(String.t()) => any()},
            :amount => float(),
            :breakdown => [
              %{
                :address => %{optional(String.t()) => any()},
                :amount => float(),
                :percentage => float()
              }
            ]
          }
          | nil
  defp governance_base_fee_breakdown(base_fee, block_number) do
    with {:ok, address_hash_string} when not is_nil(address_hash_string) <-
           CeloCoreContracts.get_address(:governance, block_number),
         {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, celo_token_address_hash} <- CeloCoreContracts.get_address(:celo_token, block_number) do
      address =
        address_hash
        # todo: Querying database in the view is not a good practice. Consider
        # refactoring.
        |> Chain.hash_to_address(@address_params)
        |> case do
          {:ok, address} -> address
          {:error, :not_found} -> nil
        end

      address_with_info =
        Helper.address_with_info(
          address,
          address_hash
        )

      celo_token = Token.get_by_contract_address_hash(celo_token_address_hash, api?: true)

      %{
        recipient: address_with_info,
        amount: base_fee,
        token:
          TokenView.render("token.json", %{
            token: celo_token,
            contract_address_hash: celo_token.contract_address_hash
          }),
        breakdown: []
      }
    else
      _ ->
        nil
    end
  end

  defp maybe_add_base_fee_info(celo_json, block_or_transaction, true) do
    base_fee_breakdown_json = render("celo_base_fee.json", block_or_transaction)
    Map.put(celo_json, "base_fee", base_fee_breakdown_json)
  end

  defp maybe_add_base_fee_info(celo_json, _block_or_transaction, false),
    do: celo_json
end
