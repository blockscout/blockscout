import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { makeContractCall, setupChart } from './utils'

export function openMakeStakeModal (event, store) {
  if (!store.getState().account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  const address = $(event.target).closest('[data-address]').data('address')

  store.getState().channel
    .push('render_make_stake', { address })
    .receive('ok', msg => {
      const $modal = $(msg.html)
      setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.staked_amount)
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

  const minStake = new BigNumber(msg.min_delegator_stake)
  const stake = new BigNumber($modal.find('[delegator-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive() || stake.isLessThan(minStake)) {
    openErrorModal('Error', `You cannot stake less than ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  }

  makeContractCall(stakingContract.methods.stake(address, stake.toString()), store)
}
