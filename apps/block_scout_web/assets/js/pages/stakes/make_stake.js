import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openErrorModal, openModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
import { makeContractCall, setupChart, isSupportedNetwork, isStakingAllowed } from './utils'

export function openMakeStakeModal (event, store) {
  const state = store.getState()

  if (!state.account) {
    openWarningModal('Unauthorized', 'You haven\'t approved the reading of account list from your MetaMask or the latest MetaMask is not installed.')
    return
  }

  if (!isSupportedNetwork(store)) return
  if (!isStakingAllowed(state)) return

  const address = $(event.target).closest('[data-address]').data('address') || store.getState().account

  state.channel
    .push('render_make_stake', { address })
    .receive('ok', msg => {
      const $modal = $(msg.html)
      const $form = $modal.find('form')

      setupChart($modal.find('.js-stakes-progress'), msg.self_staked_amount, msg.total_staked_amount)

      setupValidation(
        $form,
        {
          'delegator-stake': value => isDelegatorStakeValid(value, store, msg, address)
        },
        $modal.find('form button')
      )

      $modal.find('[data-available-amount]').click(e => {
        const amount = $(e.currentTarget).data('available-amount')
        $('[delegator-stake]', $form).val(amount).trigger('input')
        $('.tooltip').tooltip('hide')
        return false
      })

      $form.submit(() => {
        makeStake($modal, address, store, msg)
        return false
      })

      openModal($modal)
    })
}

async function makeStake ($modal, address, store, msg) {
  const state = store.getState()
  const stakingContract = state.stakingContract
  const validatorSetContract = state.validatorSetContract
  const decimals = state.tokenDecimals

  const stake = new BigNumber($modal.find('[delegator-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!isSupportedNetwork(store)) return
  if (!isStakingAllowed(state)) return
  lockModal($modal)

  let miningAddress = msg.mining_address
  if (!miningAddress || miningAddress === '0x0000000000000000000000000000000000000000') {
    miningAddress = await validatorSetContract.methods.miningByStakingAddress(address).call()
  }

  const isBanned = await validatorSetContract.methods.isValidatorBanned(miningAddress).call()
  if (isBanned) {
    openErrorModal('This pool is banned', 'You cannot stake into a banned pool.')
    return
  }

  makeContractCall(stakingContract.methods.stake(address, stake.toString()), store)
}

function isDelegatorStakeValid (value, store, msg, address) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_stake)
  const currentStake = new BigNumber(msg.delegator_staked)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const account = store.getState().account

  if (!stake.isPositive() || stake.isZero()) {
    return 'Invalid amount'
  } else if (stake.plus(currentStake).isLessThan(minStake)) {
    const staker = (account.toLowerCase() === address.toLowerCase()) ? 'candidate' : 'delegate'
    return `Minimum ${staker} stake is ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`
  } else if (stake.isGreaterThan(balance)) {
    return 'Insufficient funds'
  }

  return true
}
