defmodule BlockScoutWeb.API.V2.CeloView do
  @moduledoc """
  View functions for rendering Celo-related data in JSON format.
  """
  use BlockScoutWeb, :view

  require Logger

  import Explorer.Chain.SmartContract, only: [dead_address_hash_string: 0]

  alias BlockScoutWeb.API.V2.{Helper, TokenTransferView, TokenView, TransactionView}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.{CeloCoreContracts, CeloEpochs}
  alias Explorer.Chain.Celo.Helper, as: CeloHelper
  alias Explorer.Chain.Celo.{Epoch, EpochReward}
  alias Explorer.Chain.{Block, Token, TokenTransfer, Transaction, Wei}

  @address_params [
    necessity_by_association: %{
      :names => :optional,
      :smart_contract => :optional,
      proxy_implementations_association() => :optional
    },
    api?: true
  ]

  def render("celo_epochs.json", %{
        epochs: epochs,
        next_page_params: next_page_params
      }) do
    %{
      items: Enum.map(epochs, &prepare_epoch/1),
      next_page_params: next_page_params
    }
  end

  def render("celo_epoch.json", %{
        epoch: epoch,
        aggregated_election_rewards: aggregated_election_rewards
      }) do
    distribution_json =
      epoch.distribution
      |> prepare_distribution()

    aggregated_election_rewards_json =
      epoch
      |> prepare_aggregated_election_rewards(aggregated_election_rewards)

    %{
      number: epoch.number,
      type: epoch_type(epoch),
      is_finalized: epoch.fetched?,
      start_block_number: epoch.start_block_number,
      end_block_number: epoch.end_block_number,
      distribution: distribution_json,
      aggregated_election_rewards: aggregated_election_rewards_json,
      timestamp: epoch.end_processing_block && epoch.end_processing_block.timestamp,
      start_processing_block_hash: epoch.start_processing_block && epoch.start_processing_block.hash,
      start_processing_block_number: epoch.start_processing_block && epoch.start_processing_block.number,
      end_processing_block_hash: epoch.end_processing_block && epoch.end_processing_block.hash,
      end_processing_block_number: epoch.end_processing_block && epoch.end_processing_block.number
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

  def render("celo_epoch_election_rewards.json", %{
        rewards: rewards,
        next_page_params: next_page_params
      }) do
    rewards_json =
      rewards
      |> Enum.map(fn reward ->
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
      end)

    %{
      items: rewards_json,
      next_page_params: next_page_params
    }
  end

  def render("celo_address_election_rewards.json", %{
        rewards: rewards,
        next_page_params: next_page_params
      }) do
    rewards_json =
      rewards
      |> Enum.map(fn reward ->
        %{
          amount: reward.amount,
          epoch_number: reward.epoch_number,
          block_timestamp: reward.epoch.end_processing_block.timestamp,
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
      end)

    %{
      "items" => rewards_json,
      "next_page_params" => next_page_params
    }
  end

  defp prepare_aggregated_election_rewards(%Epoch{fetched?: false}, _), do: nil

  defp prepare_aggregated_election_rewards(%Epoch{} = epoch, aggregated_election_rewards) do
    aggregated_election_rewards
    |> Map.new(fn {type, %{total: total, count: count, token: token}} ->
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
    end)
    # For L2, delegated payments are implemented differently. They're
    # distributed on-demand via direct payments rather than through epoch
    # processing, so we need to handle them separately.
    |> then(fn rewards ->
      if CeloHelper.pre_migration_epoch_number?(epoch.number) do
        rewards
      else
        rewards
        |> Map.put(:delegated_payment, nil)
      end
    end)
  end

  defp epoch_type(epoch) do
    epoch.number
    |> CeloHelper.pre_migration_epoch_number?()
    |> if(do: "L1", else: "L2")
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
  def extend_block_json_response(out_json, block, single_block?) do
    epoch_number = CeloEpochs.block_number_to_epoch_number(block.number)

    l1_era_finalized_epoch_number =
      if CeloHelper.pre_migration_block_number?(block.number) and
           CeloHelper.epoch_block_number?(block.number) do
        epoch_number - 1
      else
        nil
      end

    celo_json =
      %{
        # todo: keep `is_epoch_block = false` for compatibility with frontend and remove
        # when new frontend is bound to `l1_era_finalized_epoch_number` property
        is_epoch_block: false,
        l1_era_finalized_epoch_number: l1_era_finalized_epoch_number,
        epoch_number: epoch_number
      }
      |> maybe_add_base_fee_info(block, single_block?)

    Map.put(out_json, :celo, celo_json)
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

  @spec prepare_epoch(Epoch.t()) :: map()
  defp prepare_epoch(epoch) do
    distribution_json =
      if epoch.distribution do
        community_transfer =
          epoch.distribution.community_transfer &&
            epoch.distribution.community_transfer
            |> TokenTransferView.prepare_token_transfer_total()

        carbon_offsetting_transfer =
          epoch.distribution.carbon_offsetting_transfer &&
            epoch.distribution.carbon_offsetting_transfer
            |> TokenTransferView.prepare_token_transfer_total()

        reserve_bolster_transfer =
          epoch.distribution.reserve_bolster_transfer &&
            epoch.distribution.reserve_bolster_transfer
            |> TokenTransferView.prepare_token_transfer_total()

        result = calculate_total_epoch_rewards(epoch.distribution)

        %{
          community_transfer: community_transfer,
          carbon_offsetting_transfer: carbon_offsetting_transfer,
          reserve_bolster_transfer: reserve_bolster_transfer,
          transfers_total: result && result.total
        }
      end

    %{
      number: epoch.number,
      type: epoch_type(epoch),
      start_block_number: epoch.start_block_number,
      end_block_number: epoch.end_block_number,
      timestamp: epoch.end_processing_block && epoch.end_processing_block.timestamp,
      is_finalized: epoch.fetched?,
      distribution: distribution_json
    }
  end

  @spec prepare_distribution(EpochReward.t() | nil) ::
          %{
            optional(:reserve_bolster_transfer) => nil | %{optional(String.t()) => any()},
            optional(:community_transfer) => nil | %{optional(String.t()) => any()},
            optional(:carbon_offsetting_transfer) => nil | %{optional(String.t()) => any()}
          }
          | nil
  defp prepare_distribution(%EpochReward{} = distribution) do
    transfers_json =
      Map.new(
        [
          reserve_bolster_transfer: distribution.reserve_bolster_transfer,
          community_transfer: distribution.community_transfer,
          carbon_offsetting_transfer: distribution.carbon_offsetting_transfer
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

    total = calculate_total_epoch_rewards(distribution)

    transfers_json
    |> Map.put(:transfers_total, total)
  end

  defp prepare_distribution(_), do: nil

  @doc """
  Calculates the total sum of all epoch reward transfers with token information.

  This function sums up all non-nil token transfers (reserve_bolster_transfer,
  community_transfer, carbon_offsetting_transfer) and ensures they all use the
  same token. If different tokens are found, it raises an error.

  ## Parameters
    - `transfers_map` (`map()`): Map containing the rendered token transfers.

  ## Returns
    - `%{token: map(), total: %{decimals: Decimal.t(), value: Decimal.t()}}`:
      Token info and total sum, or `nil` if no transfers exist.

  ## Raises
    - `ArgumentError`: If transfers use different tokens.

  ## Example
      iex> transfers = %{
      ...>   reserve_bolster_transfer: %{"token" => %{"address" => "0xABC..."}, "total" => %{"value" => Decimal.new("100")}},
      ...>   community_transfer: %{"token" => %{"address" => "0xABC..."}, "total" => %{"value" => Decimal.new("200")}}
      ...> }
      iex> calculate_total_epoch_rewards(transfers)
      %{
        token: %{"address" => "0xABC...", ...},
        total: %{decimals: Decimal.new("18"), value: Decimal.new("300")}
      }
  """
  @spec calculate_total_epoch_rewards(map()) :: map() | nil
  def calculate_total_epoch_rewards(distribution) do
    transfers =
      [
        distribution.reserve_bolster_transfer,
        distribution.community_transfer,
        distribution.carbon_offsetting_transfer
      ]
      |> Enum.reject(&is_nil/1)

    case transfers do
      [] ->
        nil

      [first_transfer | rest_transfers] ->
        case validate_and_extract_token(first_transfer, rest_transfers) do
          {:ok, token} ->
            total_value =
              transfers
              |> Enum.map(&(&1 |> TokenTransferView.prepare_token_transfer_total() |> Map.get("value")))
              |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

            token_json =
              TokenView.render("token.json", %{
                token: token,
                contract_address_hash: token.contract_address_hash
              })

            %{
              token: token_json,
              total: %{
                decimals: token.decimals,
                value: total_value
              }
            }

          :error ->
            raise ArgumentError,
                  "All transfers must use the same token, but found different tokens: #{inspect(transfers)}"
        end
    end
  end

  @spec validate_and_extract_token(TokenTransfer.t(), [TokenTransfer.t()]) ::
          {:ok, Token.t()} | :error
  defp validate_and_extract_token(first_transfer, rest_transfers) do
    with token when not is_nil(token) <- first_transfer.token,
         true <-
           Enum.all?(
             rest_transfers,
             &(&1.token && &1.token.contract_address_hash == token.contract_address_hash)
           ) do
      {:ok, token}
    else
      _ -> :error
    end
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
