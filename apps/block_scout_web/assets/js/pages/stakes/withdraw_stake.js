import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openQuestionModal, lockModal } from '../../lib/modals'
import { makeContractCall, setupChart } from './utils'

export function openWithdrawStakeModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_withdraw_stake', { address })
    .receive('ok', msg => {
      if (msg.claim_html && msg.withdraw_html) {
        openQuestionModal(
          'Claim or order', 'Do you want withdraw or claim ordered withdraw?',
          () => setupClaimWithdrawModal(address, store, msg),
          () => setupWithdrawStakeModal(address, store, msg),
          'Claim', 'Withdraw'
        )
      } else if (msg.claim_html) {
        setupClaimWithdrawModal(address, store, msg)
      } else {
        setupWithdrawStakeModal(address, store, msg)
      }
    })
}

function setupClaimWithdrawModal (address, store, msg) {
  const $modal = $(msg.claim_html)
  setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
  $modal.find('form').submit(() => {
    claimWithdraw($modal, address, store)
    return false
  })
  openModal($modal)
}

function setupWithdrawStakeModal (address, store, msg) {
  const $modal = $(msg.withdraw_html)
  setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
  $modal.find('.btn-full-primary.withdraw').click(() => {
    withdrawStake($modal, address, store, msg)
    return false
  })
  $modal.find('.btn-full-primary.order-withdraw').click(() => {
    orderWithdraw($modal, address, store, msg)
    return false
  })
  openModal($modal)
}

function claimWithdraw ($modal, address, store) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract

  makeContractCall(stakingContract.methods.claimOrderedWithdraw(address), store)
}

function withdrawStake ($modal, address, store, msg) {
  lockModal($modal, $modal.find('.btn-full-primary.withdraw'))

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const maxAllowed = new BigNumber(msg.max_withdraw_allowed)

  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!amount.isPositive() || amount.isGreaterThan(maxAllowed)) {
    openErrorModal('Error', `You cannot withdraw more than ${maxAllowed.shiftedBy(-decimals)} ${store.getState().tokenSymbol} from this pool`)
    return false
  }

  if (amount.isLessThan(currentStake) && currentStake.minus(amount).isLessThan(minStake)) {
    openErrorModal('Error', `You can't leave less than ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} in the pool`)
    return false
  }

  makeContractCall(stakingContract.methods.withdraw(address, amount.toString()), store)
}

function orderWithdraw ($modal, address, store, msg) {
  lockModal($modal, $modal.find('.btn-full-primary.order-withdraw'))

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const orderedWithdraw = new BigNumber(msg.ordered_withdraw)
  const maxAllowed = new BigNumber(msg.max_ordered_withdraw_allowed)

  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (amount.isGreaterThan(maxAllowed)) {
    openErrorModal('Error', `You cannot withdraw more than ${maxAllowed.shiftedBy(-decimals)} ${store.getState().tokenSymbol} from this pool`)
    return false
  }

  if (amount.isLessThan(orderedWithdraw.negated())) {
    openErrorModal('Error', `You cannot reduce withdrawal by more than ${orderedWithdraw.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  }

  if (amount.isLessThan(currentStake) && currentStake.minus(amount).isLessThan(minStake)) {
    openErrorModal('Error', `You can't leave less than ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} in the pool`)
    return false
  }

  makeContractCall(stakingContract.methods.orderWithdraw(address, amount.toString()), store)
}
