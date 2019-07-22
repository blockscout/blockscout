import $ from 'jquery'
import humps from 'humps'
import * as modals from './utils.js'

window.openMakeStakeModal = async function (poolAddress) {
  let modal = '#stakeModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    modals.setProgressInfo(modal, pool)

    $(`${modal} form`).unbind('submit')
    $(`${modal} form`).on('submit', (e) => modals.makeStake(e, modal, poolAddress))

    $(modal).modal('show')
  } catch (_) {
    $(modal).modal('hide')
    modals.openErrorModal('Error', 'Something went wrong')
  }
}
