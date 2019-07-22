import $ from 'jquery'
import humps from 'humps'
import {store} from '../pages/stakes.js'
import * as modals from './utils.js'

window.openMoveStakeModal = async function (poolAddress) {
  let modal = '#moveStakeModal'

  try {
    let responseforPool = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(responseforPool.pool)
    let relation = humps.camelizeKeys(responseforPool.relation)
    let response = await $.getJSON('/staking_pools')
    let pools = []

    $.each(response.pools, (_key, pool) => {
      let p = humps.camelizeKeys(pool)
      if (p.stakingAddressHash !== poolAddress) {
        pools.push(p)
      }
    })

    modals.setProgressInfo(modal, pool)
    let tokenSymbol = store.getState().tokenSymbol
    $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)
    $(`${modal} [max-allowed]`).text(`${relation.maxWithdrawAllowed} ${tokenSymbol}`)

    $.each($(`${modal} [pool-select] option:not(:first-child)`), (_, opt) => {
      opt.remove()
    })

    $.each(pools, (_key, pool) => {
      var $option = $('<option/>', {
        value: pool.stakingAddressHash,
        text: pool.stakingAddressHash.slice(0, 13)
      })
      $(`${modal} [pool-select]`).append($option)
    })

    $(`${modal} [pool-select]`).on('change', e => {
      let selectedAddress = e.currentTarget.value
      let amount = $(`${modal} [move-amount]`).val()
      window.openMoveStakeSelectedModal(poolAddress, selectedAddress, amount, pools)
      $(modal).modal('hide')
    })

    $(modal).modal('show')
  } catch (err) {
    console.log(err)
    $(modal).modal('hide')
    modals.openErrorModal('Error', 'Something went wrong')
  }
}
