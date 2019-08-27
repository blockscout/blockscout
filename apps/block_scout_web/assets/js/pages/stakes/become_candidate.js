import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { makeContractCall } from './utils'

export function openBecomeCandidateModal (store) {
  if (!store.getState().account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  store.getState().channel
    .push('render_become_candidate')
    .receive('ok', msg => {
      const $modal = $(msg.html)
      let errors = new Map()
      $modal.find('form').submit(() => {
        becomeCandidate($modal, store, msg)
        return false
      })

      $modal.find('[candidate-stake]').blur((event) => {
        const isValid = validateCandidateStakeInput(event.target, store, msg)
        updateErrors(errors, isValid, event.target)
      })

      $modal.find('[mining-address]').blur((event) => {
        const isValid = validateMiningAddressInput(event.target, store)
        updateErrors(errors, isValid, event.target)
      })

      openModal($modal)
    })
}

async function becomeCandidate ($modal, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const blockRewardContract = store.getState().blockRewardContract
  const decimals = store.getState().tokenDecimals
  const stake = new BigNumber($modal.find('[candidate-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const miningAddress = $modal.find('[mining-address]').val().trim().toLowerCase()

  try {
    if (!await stakingContract.methods.areStakeAndWithdrawAllowed().call()) {
      if (await blockRewardContract.methods.isSnapshotting().call()) {
        openErrorModal('Error', 'Stakes are not allowed at the moment. Please try again in a few blocks')
      } else {
        openErrorModal('Error', 'Current staking epoch is finishing now, you will be able to place a stake during the next staking epoch. Please try again in a few blocks')
      }
      return false
    }

    if (msg.pool_exists) {
      makeContractCall(stakingContract.methods.stake(store.getState().account, stake.toString()), store)
    } else {
      makeContractCall(stakingContract.methods.addPool(stake.toString(), miningAddress), store)
    }
  } catch (err) {
    openErrorModal('Error', err.message)
  }
}

function validateCandidateStakeInput (input, store, msg) {
  if (!$(input).val()) {
    hideInputError(input)
    return true
  }

  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_candidate_stake)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber($(input).val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive() || stake.isLessThan(minStake)) {
    displayInputError(input, `You cannot stake less than ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  } else if (stake.isGreaterThan(balance)) {
    displayInputError(input, `You cannot stake more than ${balance.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  }

  hideInputError(input)
  return true
}

function validateMiningAddressInput (input, store) {
  if (!$(input).val()) {
    hideInputError(input)
    return true
  }

  const web3 = store.getState().web3
  const miningAddress = $(input).val().trim().toLowerCase()

  if (miningAddress === store.getState().account || !web3.utils.isAddress(miningAddress)) {
    displayInputError(input, 'Invalid Mining Address')
    return false
  }

  hideInputError(input)
  return true
}

function displayInputError (input, message) {
  const group = $(input).parent('.input-group')

  group.addClass('input-status-error')
  group.find('.input-group-message').html(message)
}

function hideInputError (input) {
  const group = $(input).parent('.input-group')

  group.removeClass('input-status-error')
  group.find('.input-group-message').html('')
}

function updateErrors (errors, isValid, input) {
  if (isValid) {
    errors.delete($(input).attr('id'))

    if (errors.size) {
      disableSubmit(input, true)
    } else {
      disableSubmit(input, false)
    }

    return errors
  }

  errors.set($(input).attr('id'), input)
  disableSubmit(input, true)
  return errors
}

function disableSubmit (input, disabled) {
  $(input).closest('form').find('button').attr('disabled', disabled)
}
