import $ from 'jquery'
import URI from 'urijs'
import humps from 'humps'
import socket from '../socket'

if (window.page === 'address') {
  const channel = socket.channel(`addresses:${window.addressHash}`, {})
  channel.join()
    .receive('ok', resp => { console.log('Joined successfully', `addresses:${window.addressHash}`, resp) })
    .receive('error', resp => { console.log('Unable to join', `addresses:${window.addressHash}`, resp) })

  const currentLocation = URI(window.location)
  if(!currentLocation.hasQuery('block_number')) {
    const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
    if ($emptyTransactionsList) {
      channel.on('transaction', () => {
        window.location.reload()
      })
    }

    const $transactionsList = $('[data-selector="transactions-list"]')
    if ($transactionsList) {
      channel.on('transaction', (msg) => {
        const {
          toAddressHash,
          fromAddressHash,
          transactionHtml
        } = humps.camelizeKeys(msg)

        if(currentLocation.query(true).filter === 'to' && toAddressHash !== window.addressHash) {
          return;
        }
        if(currentLocation.query(true).filter === 'from' && fromAddressHash !== window.addressHash) {
          return;
        }

        $transactionsList.prepend(transactionHtml)
      })
    }
  }
}
