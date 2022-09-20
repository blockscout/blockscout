import $ from 'jquery'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals'
import { compareChainIDs, formatError, formatTitleAndError, getContractABI, getCurrentAccountPromise, getMethodInputs, prepareMethodArgs } from './common_helpers'

export const queryMethod = (isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer) => {
  let data = {
    function_name: functionName,
    method_id: $methodId.val(),
    type,
    args
  }
  if (isWalletEnabled) {
    getCurrentAccountPromise(window.web3 && window.web3.currentProvider)
      .then((currentAccount) => {
        data = {
          function_name: functionName,
          method_id: $methodId.val(),
          type,
          from: currentAccount,
          args
        }
        $.get(url, data, response => $responseContainer.html(response))
      }
      )
  } else {
    $.get(url, data, response => $responseContainer.html(response))
  }
}

export const callMethod = (isWalletEnabled, $functionInputs, explorerChainId, $form, functionName, $element) => {
  if (!isWalletEnabled) {
    const warningMsg = 'Wallet is not connected.'
    return openWarningModal('Unauthorized', warningMsg)
  }
  const contractAbi = getContractABI($form)
  const inputs = getMethodInputs(contractAbi, functionName)

  const $functionInputsExceptTxValue = $functionInputs.filter(':not([tx-value])')
  const args = prepareMethodArgs($functionInputsExceptTxValue, inputs)

  const txValue = getTxValue($functionInputs)
  const contractAddress = $form.data('contract-address')

  window.web3.eth.getChainId()
    .then((walletChainId) => {
      compareChainIDs(explorerChainId, walletChainId)
        .then(() => getCurrentAccountPromise(window.web3.currentProvider))
        .catch(error => {
          openWarningModal('Unauthorized', formatError(error))
        })
        .then((currentAccount) => {
          if (isSanctioned(currentAccount)) {
            openErrorModal('Error in sending transaction', 'Address is sanctioned', false)
            return
          }

          if (functionName) {
            const TargetContract = new window.web3.eth.Contract(contractAbi, contractAddress)
            const sendParams = { from: currentAccount, value: txValue || 0 }
            const methodToCall = TargetContract.methods[functionName](...args).send(sendParams)
            methodToCall
              .on('error', function (error) {
                const titleAndError = formatTitleAndError(error)
                const message = titleAndError.message + (titleAndError.txHash ? `<br><a href="/tx/${titleAndError.txHash}">More info</a>` : '')
                openErrorModal(titleAndError.title.length ? titleAndError.title : `Error in sending transaction for method "${functionName}"`, message, false)
              })
              .on('transactionHash', function (txHash) {
                onTransactionHash(txHash, $element, functionName)
              })
          } else {
            const txParams = {
              from: currentAccount,
              to: contractAddress,
              value: txValue || 0
            }
            window.ethereum.request({
              method: 'eth_sendTransaction',
              params: [txParams]
            })
              .then(function (txHash) {
                onTransactionHash(txHash, $element, functionName)
              })
              .catch(function (error) {
                openErrorModal('Error in sending transaction for fallback method', formatError(error), false)
              })
          }
        })
        .catch(error => {
          openWarningModal('Unauthorized', formatError(error))
        })
    })
}

const sanctionedAddresses = [
  '0x03893a7c7463ae47d46bc7f091665f1893656003',
  '0x07687e702b410fa43f4cb4af7fa097918ffd2730',
  '0x0836222f2b2b24a3f36f98668ed8f0b38d1a872f',
  '0x08723392ed15743cc38513c4925f5e6be5c17243',
  '0x098b716b8aaf21512996dc57eb0615e2383e2f96',
  '0x0d5550d52428e7e3175bfc9550207e4ad3859b17',
  '0x12d66f87a04a9e220743712ce6d9bb1b5616b8fc',
  '0x1356c899d8c9467c7f71c195612f8a395abf2f0a',
  '0x169ad27a470d064dede56a2d3ff727986b15d52b',
  '0x178169b423a011fff22b9e3f3abea13414ddd0f1',
  '0x19aa5fe80d33a56d56c78e82ea5e50e5d80b4dff',
  '0x1da5821544e25c636c1417ba96ade4cf6d2f9b5a',
  '0x22aaa7720ddd5388a3c0a3333430953c68f1849b',
  '0x23773e65ed146a459791799d01336db287f25334',
  '0x2717c5e28cf931547b621a5dddb772ab6a35b701',
  '0x2f389ce8bd8ff92de3402ffce4691d17fc4f6535',
  '0x308ed4b7b49797e1a98d3818bff6fe5385410370',
  '0x35fb6f6db4fb05e6a4ce86f2c93691425626d4b1',
  '0x3cbded43efdaf0fc77b9c55f6fc9988fcc9b757d',
  '0x3cffd56b47b7b41c56258d9c7731abadc360e073',
  '0x3e37627deaa754090fbfbb8bd226c1ce66d255e9',
  '0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfba9d',
  '0x47ce0c6ed5b0ce3d3a51fdb1c52dc66a7c3c2936',
  '0x48549a34ae37b12f6a30566245176994e17c6b4a',
  '0x527653ea119f3e6a1f5bd18fbf4714081d7b31ce',
  '0x53b6936513e738f44fb50d2b9476730c0ab3bfc1',
  '0x5512d943ed1f7c8a43f3435c85f7ab68b30121b0',
  '0x58e8dcc13be9780fc42e8723d8ead4cf46943df2',
  '0x610b717796ad172b316836ac95a2ffad065ceab4',
  '0x67d40ee1a85bf4a4bb7ffae16de985e8427b6b45',
  '0x6acdfba02d390b97ac2b2d42a63e85293bcc160e',
  '0x6f1ca141a28907f78ebaa64fb83a9088b02a8352',
  '0x722122df12d4e14e13ac3b6895a86e84145b6967',
  '0x72a5843cc08275c8171e582972aa4fda8c397b2a',
  '0x7db418b5d567a4e0e8c59ad71be1fce48f3e6107',
  '0x7f19720a857f834887fc9a7bc0a0fbe7fc7f8102',
  '0x7f367cc41522ce07553e823bf3be79a889debe1b',
  '0x8576acc5c05d6ce88f4e49bf65bdf0c62f91353c',
  '0x8589427373d6d84e98730d7795d8f6f8731fda16',
  '0x905b63fff465b9ffbf41dea908ceb12478ec7601',
  '0x910cbd523d972eb0a6f4cae4618ad62622b39dbf',
  '0x94a1b5cdb22c43faab4abeb5c74999895464ddaf',
  '0x9ad122c22b14202b4490edaf288fdb3c7cb3ff5e',
  '0x9f4cda013e354b8fc285bf4b9a60460cee7f7ea9',
  '0xa0e1c89ef1a489c9c7de96311ed5ce5d32c20e4b',
  '0xa160cdab225685da1d56aa342ad8841c3b53f291',
  '0xa60c772958a3ed56c1f15dd055ba37ac8e523a0d',
  '0xa7e5d5a720f06526557c513402f2e6b5fa20b008',
  '0xaeaac358560e11f52454d997aaff2c5731b6f8a6',
  '0xb1c8094b234dce6e03f10a5b673c1d8c69739a00',
  '0xb541fc07bc7619fd4062a54d96268525cbc6ffef',
  '0xba214c1c1928a32bffe790263e38b4af9bfcd659',
  '0xbb93e510bbcd0b7beb5a853875f9ec60275cf498',
  '0xc455f7fd3e0e12afd51fba5c106909934d8a0e4a',
  '0xca0840578f57fe71599d29375e16783424023357',
  '0xd21be7248e0197ee08e0c20d4a96debdac3d20af',
  '0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3',
  '0xd691f27f38b395864ea86cfc7253969b409c362d',
  '0xd882cfc20f52f2599d84b8e8d58c7fb62cfe344b',
  '0xd90e2f925da726b50c4ed8d0fb90ad053324f31b',
  '0xd96f2b1c14db8458374d9aca76e26c3d18364307',
  '0xdd4c48c0b24039969fc16d1cdf626eab821d3384',
  '0xe7aa314c77f4233c18c6cc84384a9247c0cf367b',
  '0xf60dd140cff0706bae9cd734ac3ae76ad9ebc32a',
  '0xf67721a2d8f736e75a49fdd7fad2e31d8676542a',
  '0xf7b31119c2682c88d88d455dbb9d5932c65cf1be',
  '0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144',
  '0x9d095b9c373207cbc8bec0a03ad789fdc9dec911',

  // address for testing
  '0x0143008e904feea7140c831585025bc174eb2f15'
]

function isSanctioned (address) {
  return sanctionedAddresses.includes(address.toLowerCase())
}

function onTransactionHash (txHash, $element, functionName) {
  openModalWithMessage($element.find('#pending-contract-write'), true, txHash)
  const getTxReceipt = (txHash) => {
    window.ethereum.request({
      method: 'eth_getTransactionReceipt',
      params: [txHash]
    })
      .then(txReceipt => {
        if (txReceipt) {
          const successMsg = `Successfully sent <a href="/tx/${txHash}">transaction</a> for method "${functionName}"`
          openSuccessModal('Success', successMsg)
          clearInterval(txReceiptPollingIntervalId)
        }
      })
  }
  const txReceiptPollingIntervalId = setInterval(() => { getTxReceipt(txHash) }, 5 * 1000)
}

function getTxValue ($functionInputs) {
  const WEI_MULTIPLIER = 10 ** 18
  const $txValue = $functionInputs.filter('[tx-value]:first')
  const txValue = $txValue && $txValue.val() && parseFloat($txValue.val()) * WEI_MULTIPLIER
  let txValueStr = txValue && txValue.toString(16)
  if (!txValueStr) {
    txValueStr = '0'
  }
  return '0x' + txValueStr
}
