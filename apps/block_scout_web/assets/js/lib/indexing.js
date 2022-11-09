import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'

function tryUpdateIndexedStatus (el, indexedRatioBlocks = el.dataset.indexedRatioBlocks, indexedRatio = el.dataset.indexedRatio, indexingFinished = false) {
  if (indexingFinished) return $("[data-selector='indexed-status']").remove()
  const indexedRatioFloat = parseFloat(indexedRatio)
  const indexedRatioBlocksFloat = parseFloat(indexedRatioBlocks)

  if (!isNaN(indexedRatioBlocksFloat)) {
    el.dataset.indexedRatioBlocks = indexedRatioBlocks
  } else if (!isNaN(indexedRatioFloat)) {
    el.dataset.indexedRatio = indexedRatio
  }

  const blocksPercentComplete = numeral(el.dataset.indexedRatioBlocks).format('0%')
  let indexedText
  if (blocksPercentComplete === '100%') {
    const intTxsPercentComplete = numeral(el.dataset.indexedRatio).format('0%')
    indexedText = `${intTxsPercentComplete} ${window.localized['Blocks With Internal Transactions Indexed']}`
  } else {
    indexedText = `${blocksPercentComplete} Blocks Indexed`
  }

  if (indexedText !== el.innerHTML) {
    el.innerHTML = indexedText
  }
}

export function updateIndexStatus (msg = {}, type) {
  $('[data-indexed-ratio]').each((i, el) => {
    if (type === 'blocks') {
      tryUpdateIndexedStatus(el, msg.ratio, null, msg.finished)
    } else if (type === 'internal_transactions') {
      tryUpdateIndexedStatus(el, null, msg.ratio, msg.finished)
    } else {
      tryUpdateIndexedStatus(el, null, null, msg.finished)
    }
  })
}
updateIndexStatus()

const IndexingChannelBlocks = socket.channel('blocks:indexing')
IndexingChannelBlocks.join()
IndexingChannelBlocks.on('index_status', (msg) => updateIndexStatus(humps.camelizeKeys(msg), 'blocks'))

const indexingChannelInternalTransactions = socket.channel('blocks:indexing_internal_transactions')
indexingChannelInternalTransactions.join()
indexingChannelInternalTransactions.on('index_status', (msg) => updateIndexStatus(humps.camelizeKeys(msg), 'internal_transactions'))
