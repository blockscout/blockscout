import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openQuestionModal, lockModal } from '../../lib/modals'
import { makeContractCall, setupChart } from './utils'

export function openWithdrawStakeModal (event, store) {
  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_withdraw_stake', { address })
    .receive('ok', msg => {
      if (msg.claim_html) {
        openQuestionModal(
          'Claim or order', 'Do you want withdraw or claim ordered withdraw?',
          () => setupClaimWithdrawModal(address, store, msg),
          () => setupWithdrawStakeModal(address, store, msg),
          'Claim', 'Withdraw'
        )
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
  const $modal = $(msg.html)
  setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
  $modal.find('.btn-full-primary.withdraw').click(() => {
    withdrawStake($modal, address, store)
    return false
  })
  $modal.find('.btn-full-primary.order-withdraw').click(() => {
    orderWithdraw($modal, address, store)
    return false
  })
  openModal($modal)
}

function claimWithdraw ($modal, address, store) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract

  makeContractCall(stakingContract.methods.claimOrderedWithdraw(address), store)
}

function withdrawStake ($modal, address, store) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals

  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  makeContractCall(stakingContract.methods.withdraw(address, amount.toString()), store)
}

function orderWithdraw ($modal, address, store) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals

  const amount = new BigNumber($modal.find('[amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  makeContractCall(stakingContract.methods.orderWithdraw(address, amount.toString()), store)
}
