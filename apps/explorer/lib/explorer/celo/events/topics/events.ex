defmodule Explorer.Celo.Events do
  @moduledoc """
    Helper methods and event groups which define Celo contract event topics
  """

  use Explorer.Celo.EventTypes

  @doc """
    Events for updating account
  """
  def account_events,
    do: [
      @gold_withdrawn,
      @gold_unlocked,
      @gold_locked,
      @account_created,
      @account_wallet_address_set,
      @account_url_set,
      @account_name_set,
      @account_data_encryption_key_set,
      @validator_group_pending_vote_revoked,
      @validator_group_active_vote_revoked,
      @validator_group_vote_activated,
      @validator_group_vote_cast,
      @validator_group_epoch_rewards_distributed,
      @validator_epoch_payment_distributed,
      @validator_registered,
      @validator_group_registered
    ]

  @doc """
    Events for updating validator
  """
  def validator_events,
    do: [
      @validator_registered,
      @validator_affiliated,
      @validator_deaffiliated,
      @validator_score_updated,
      @validator_signer_authorized,
      @validator_epoch_payment_distributed
    ]

  def membership_events,
    do: [
      @validator_group_member_added,
      @validator_group_member_removed,
      @validator_group_member_reordered
    ]

  @doc """
      Events for updating validator group
  """
  def validator_group_events,
    do: [
      @validator_group_epoch_rewards_distributed,
      @validator_group_commission_updated,
      @validator_group_registered,
      @validator_group_deregistered
    ]

  def validator_group_voter_reward_events,
    do: [
      @validator_group_epoch_rewards_distributed
    ]

  def vote_events,
    do: [
      @validator_group_pending_vote_revoked,
      @validator_group_active_vote_revoked,
      @validator_group_vote_cast
    ]

  @doc """
      Events for notifications
  """
  def withdrawal_events,
    do: [
      @gold_withdrawn,
      @gold_unlocked,
      @gold_locked
    ]

  def gold_unlocked,
    do: [
      @gold_unlocked
    ]

  def gold_withdrawn,
    do: [
      @gold_withdrawn
    ]

  def signer_events,
    do: [
      @validator_signer_authorized,
      @vote_signer_authorized,
      @attestation_signer_authorized
    ]

  @doc """
    Events for updating voter
  """
  def voter_events,
    do: [
      @validator_group_active_vote_revoked,
      @validator_group_pending_vote_revoked,
      @validator_group_vote_activated,
      @validator_group_vote_cast
    ]

  def distributed_events,
    do: [
      @voter_rewards
    ]

  def attestation_issuer_selected_event,
    do: @attestation_issuer_selected

  def attestation_completed_event,
    do: @attestation_completed

  def oracle_reported_event,
    do: @oracle_reported

  def account_name_event,
    do: @account_name_set

  def account_wallet_address_set_event,
    do: @account_wallet_address_set
end
