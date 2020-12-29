import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
import { makeContractCall, setupChart, isSupportedNetwork } from './utils'

export function openMoveStakeModal (event, store) {
  if (!isSupportedNetwork(store)) return

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
  const $form = $modal.find('form')

  setupChart($modal.find('.js-pool-from-progress'), msg.from.self_staked_amount, msg.from.total_staked_amount)
  if (msg.to) {
    setupChart($modal.find('.js-pool-to-progress'), msg.to.self_staked_amount, msg.to.total_staked_amount)

    setupValidation(
      $form,
      {
        'move-amount': value => isMoveAmountValid(value, store, msg)
      },
      $modal.find('form button')
    )
  }

  $form.submit(() => {
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
        $modal.modal('show')
        setupModal($modal, fromAddress, store, msg)
      })
  })
  $modal.find('[data-available-amount]').click(e => {
    const amount = $(e.currentTarget).data('available-amount')
    $('[move-amount]', $form).val(amount).trigger('input')
    $('.tooltip').tooltip('hide')
    return false
  })
}

function moveStake ($modal, fromAddress, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals
  const stake = new BigNumber($modal.find('[move-amount]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  const toAddress = $modal.find('[pool-select]').val()
  makeContractCall(stakingContract.methods.moveStake(fromAddress, toAddress, stake.toFixed()), store)
}

function isMoveAmountValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minFromStake = new BigNumber(msg.from.min_stake)
  const minToStake = (msg.to) ? new BigNumber(msg.to.min_stake) : null
  const maxAllowed = new BigNumber(msg.max_withdraw_allowed)
  const currentFromStake = new BigNumber(msg.from.stake_amount)
  const currentToStake = (msg.to) ? new BigNumber(msg.to.stake_amount) : null
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive() || stake.isZero()) {
    return 'Invalid amount'
  } else if (stake.plus(currentToStake).isLessThan(minToStake)) {
    return `You must move at least ${minToStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} to the selected pool`
  } else if (stake.isGreaterThan(maxAllowed)) {
    return `You have ${maxAllowed.shiftedBy(-decimals)} ${store.getState().tokenSymbol} available to move`
  } else if (stake.isLessThan(currentFromStake) && currentFromStake.minus(stake).isLessThan(minFromStake)) {
    return `A minimum of ${minFromStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol} is required to remain in the current pool, or move the entire amount to leave this pool`
  }

  return true
}
