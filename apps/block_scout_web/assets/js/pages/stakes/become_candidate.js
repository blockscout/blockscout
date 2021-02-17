import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation, displayInputError } from '../../lib/validation'
import { makeContractCall, isSupportedNetwork, isStakingAllowed } from './utils'
import constants from './constants'

let status = 'modalClosed'

export async function openBecomeCandidateModal (event, store) {
  const state = store.getState()

  if (!state.account) {
    openWarningModal('Unauthorized', constants.METAMASK_ACCOUNTS_EMPTY)
    return
  }

  if (!isSupportedNetwork(store)) return
  if (!isStakingAllowed(state)) return

  $(event.currentTarget).prop('disabled', true)
  state.channel
    .push('render_become_candidate')
    .receive('ok', msg => {
      $(event.currentTarget).prop('disabled', false)

      const $modal = $(msg.html)
      const $form = $modal.find('form')

      setupValidation(
        $form,
        {
          'candidate-stake': value => isCandidateStakeValid(value, store, msg),
          'mining-address': value => isMiningAddressValid(value, store)
        },
        $modal.find('form button')
      )

      $modal.find('[data-available-amount]').click(e => {
        const amount = $(e.currentTarget).data('available-amount')
        $('[candidate-stake]', $form).val(amount).trigger('input')
        $('.tooltip').tooltip('hide')
        return false
      })

      $form.submit(() => {
        becomeCandidate($modal, store, msg)
        return false
      })

      $modal.on('shown.bs.modal', () => {
        status = 'modalOpened'
      })
      $modal.on('hidden.bs.modal', () => {
        status = 'modalClosed'
        $modal.remove()
      })

      openModal($modal)
    })
    .receive('timeout', () => {
      $(event.currentTarget).prop('disabled', false)
      openErrorModal('Become a Candidate', 'Connection timeout')
    })
}

export function becomeCandidateConnectionLost () {
  const errorMsg = 'Connection with server is lost. Please, reload the page.'
  if (status === 'modalOpened') {
    status = 'modalClosed'
    openErrorModal('Become a Candidate', errorMsg, true)
  }
}

async function becomeCandidate ($modal, store, msg) {
  const state = store.getState()
  const stakingContract = state.stakingContract
  const tokenContract = state.tokenContract
  const decimals = state.tokenDecimals
  const stake = new BigNumber($modal.find('[candidate-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const $miningAddressInput = $modal.find('[mining-address]')
  const miningAddress = $miningAddressInput.val().trim().toLowerCase()

  try {
    if (!isSupportedNetwork(store)) return false
    if (!isStakingAllowed(state)) return false

    const validatorSetContract = state.validatorSetContract
    const stakingAddress = await validatorSetContract.methods.stakingByMiningAddress(miningAddress).call()

    if (stakingAddress !== '0x0000000000000000000000000000000000000000') {
      displayInputError($miningAddressInput, `This mining address is already bound to another staking address (<span title="${stakingAddress}">${shortenAddress(stakingAddress)}</span>). Please use another mining address.`)
      $modal.find('form button').blur()
      return false
    }

    lockModal($modal)

    makeContractCall(tokenContract.methods.transferAndCall(stakingContract.options.address, stake.toFixed(), `${miningAddress}01`), store)
  } catch (err) {
    openErrorModal('Error', err.message)
  }
}

function shortenAddress (address) {
  return address.substring(0, 6) + '–' + address.substring(address.length - 6)
}

function isCandidateStakeValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_candidate_stake)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive() || stake.isZero()) {
    return 'Invalid amount'
  } else if (stake.isLessThan(minStake)) {
    return `Minimum candidate stake is ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`
  } else if (stake.isGreaterThan(balance)) {
    return 'Insufficient funds'
  }

  return true
}

function isMiningAddressValid (value, store) {
  const web3 = store.getState().web3
  const miningAddress = value.trim().toLowerCase()

  if (!web3.utils.isAddress(miningAddress)) {
    return 'Invalid mining address'
  } else if (miningAddress === store.getState().account.toLowerCase()) {
    return 'The mining address cannot match the staking address'
  }

  return true
}
