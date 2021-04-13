import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation, displayInputError } from '../../lib/validation'
import { makeContractCall, isSupportedNetwork, isStakingAllowed } from './utils'
import constants from './constants'
import * as Sentry from '@sentry/browser'

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
          'mining-address': value => isMiningAddressValid(value, store),
          'pool-name': value => isPoolNameValid(value, store),
          'pool-description': value => isPoolDescriptionValid(value, store)
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
      const msg = 'Connection timeout'
      openErrorModal('Become a Candidate', msg)
      Sentry.captureMessage(msg)
    })
}

export function becomeCandidateConnectionLost () {
  const errorMsg = 'Connection with server is lost. Please, reload the page.'
  if (status === 'modalOpened') {
    status = 'modalClosed'
    openErrorModal('Become a Candidate', errorMsg, true)
    Sentry.captureMessage(errorMsg)
  }
}

async function becomeCandidate ($modal, store, msg) {
  const state = store.getState()
  const web3 = state.web3
  const stakingContract = state.stakingContract
  const tokenContract = state.tokenContract
  const decimals = state.tokenDecimals
  const stake = new BigNumber($modal.find('[candidate-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const $miningAddressInput = $modal.find('[mining-address]')
  const $poolNameInput = $modal.find('[pool-name]')
  const $poolDescriptionInput = $modal.find('[pool-description]')
  const miningAddress = $miningAddressInput.val().trim().toLowerCase()
  const poolName = $poolNameInput.val().trim()
  const poolDescription = $poolDescriptionInput.val().trim()

  try {
    if (!isSupportedNetwork(store)) return false
    if (!isStakingAllowed(state)) return false

    const validatorSetContract = state.validatorSetContract
    const hasEverBeenMiningAddress = await validatorSetContract.methods.hasEverBeenMiningAddress(miningAddress).call()

    if (hasEverBeenMiningAddress !== '0') {
      displayInputError($miningAddressInput, 'This mining address has already been used for another pool. Please use another mining address.')
      $modal.find('form button').blur()
      return false
    }

    lockModal($modal)

    const poolNameHex = web3.utils.stripHexPrefix(web3.utils.utf8ToHex(poolName))
    const poolNameLength = web3.utils.stripHexPrefix(web3.utils.padLeft(web3.utils.numberToHex(poolNameHex.length / 2), 2, '0'))
    const poolDescriptionHex = web3.utils.stripHexPrefix(web3.utils.utf8ToHex(poolDescription))
    const poolDescriptionLength = web3.utils.stripHexPrefix(web3.utils.padLeft(web3.utils.numberToHex(poolDescriptionHex.length / 2), 4, '0'))

    makeContractCall(tokenContract.methods.transferAndCall(stakingContract.options.address, stake.toFixed(), `${miningAddress}01${poolNameLength}${poolNameHex}${poolDescriptionLength}${poolDescriptionHex}`), store)
  } catch (err) {
    openErrorModal('Error', err.message)
    Sentry.captureException(err)
  }
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

function isPoolNameValid (name, store) {
  const web3 = store.getState().web3
  const nameHex = web3.utils.stripHexPrefix(web3.utils.utf8ToHex(name.trim()))
  const nameLength = nameHex.length / 2
  const maxLength = 256

  if (nameLength > maxLength) {
    return `Pool name length cannot exceed ${maxLength} bytes`
  } else if (nameLength === 0) {
    return 'Pool name shouldn\'t be empty'
  }

  return true
}

function isPoolDescriptionValid (description, store) {
  const web3 = store.getState().web3
  const descriptionHex = web3.utils.stripHexPrefix(web3.utils.utf8ToHex(description.trim()))
  const maxLength = 1024

  if (descriptionHex.length / 2 > maxLength) {
    return `Pool description length cannot exceed ${maxLength} bytes`
  }

  return true
}
