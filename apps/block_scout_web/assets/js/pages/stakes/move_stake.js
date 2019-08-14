import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, lockModal } from '../../lib/modals'
import { makeContractCall, setupChart } from './utils'

export function openMoveStakeModal (event, store) {
  const fromAddress = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_move_stake', { from: fromAddress, to: null, amount: null })
    .receive('ok', msg => {
      const $modal = $(msg.html)
      setupModal($modal, fromAddress, store, msg)
      openModal($modal)
    })
}

function setupModal ($modal, fromAddress, store, msg) {
  setupChart($modal.find('.js-pool-from-progress'), msg.from.self_staked_amount, msg.from.staked_amount)
  if (msg.to) {
    setupChart($modal.find('.js-pool-to-progress'), msg.to.self_staked_amount, msg.to.staked_amount)
  }

  $modal.find('form').submit(() => {
    moveStake($modal, fromAddress, store, msg)
    return false
  })
  $modal.find('[pool-select]').on('change', event => {
    const toAddress = $modal.find('[pool-select]').val()
    const amount = $modal.find('[move-amount]').val()

    store.getState().channel
      .push('render_move_stake', { from: fromAddress, to: toAddress, amount })
      .receive('ok', msg => {
        $modal.html($(msg.html).html())
        $modal.addClass('show').css('padding-right: 12px; display: block;')
        setupModal($modal, fromAddress, store, msg)
      })
  })
}

function moveStake ($modal, fromAddress, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals

  const minFromStake = new BigNumber(msg.from.min_stake)
  const minToStake = new BigNumber(msg.to.min_stake)
  const currentFromStake = new BigNumber(msg.from.stake_amount)
  const currentToStake = new BigNumber(msg.to.stake_amount)
  const maxAllowed = new BigNumber(msg.max_withdraw_allowed)
  const stake = new BigNumber($modal.find('[move-amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive() || stake.plus(currentToStake).isLessThan(minToStake)) {
    openErrorModal('Error', `You cannot move less than ${minToStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} to this pool`)
    return false
  }

  if (stake.isGreaterThan(maxAllowed)) {
    openErrorModal('Error', `You cannot move more than ${maxAllowed.shiftedBy(-decimals)} ${store.getState().tokenSymbol} right now`)
    return false
  }

  if (stake.isLessThan(currentFromStake) && currentFromStake.minus(stake).isLessThan(minFromStake)) {
    openErrorModal('Error', `You can't leave less than ${minFromStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} in the source pool`)
    return false
  }

  const toAddress = $modal.find('[pool-select]').val()
  makeContractCall(stakingContract.methods.moveStake(fromAddress, toAddress, stake.toString()), store)
}
