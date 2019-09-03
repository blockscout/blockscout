import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
import { makeContractCall, setupChart } from './utils'

export function openMakeStakeModal (event, store) {
  if (!store.getState().account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  const address = $(event.target).closest('[data-address]').data('address') || store.getState().account

  store.getState().channel
    .push('render_make_stake', { address })
    .receive('ok', msg => {
      const $modal = $(msg.html)
      setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
      setupValidation(
        $modal.find('form'),
        {
          'delegator-stake': value => isDelegatorStakeValid(value, store, msg, address)
        },
        $modal.find('form button')
      )

      $modal.find('form').submit(() => {
        makeStake($modal, address, store, msg)
        return false
      })
      openModal($modal)
    })
}

function makeStake ($modal, address, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const decimals = store.getState().tokenDecimals

  const stake = new BigNumber($modal.find('[delegator-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  makeContractCall(stakingContract.methods.stake(address, stake.toString()), store)
}

function isDelegatorStakeValid (value, store, msg, address) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const account = store.getState().account

  if (!stake.isPositive()) {
    return 'Invalid amount'
  } else if (stake.plus(currentStake).isLessThan(minStake)) {
    const staker = (account === address) ? 'candidate' : 'delegate'
    return `Minimum ${staker} stake is ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`
  } else if (stake.isGreaterThan(balance)) {
    return 'Insufficient funds'
  }

  return true
}
