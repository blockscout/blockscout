import $ from 'jquery'
import { openErrorModal, openWarningModal, openSuccessModal, openModalWithMessage } from '../modals'
import { compareChainIDs, formatError, formatTitleAndError, getContractABI, getCurrentAccountPromise, getMethodInputs, prepareMethodArgs } from './common_helpers'
import { fullPath } from '../utils'

export const queryMethod = (isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer) => {
  const data = {
    function_name: functionName,
    method_id: $methodId.val(),
    type
  }

  data.args_count = args.length
  let i = args.length

  while (i--) {
    data['arg_' + i] = args[i]
  }

  if (isWalletEnabled) {
    getCurrentAccountPromise(window.web3 && window.web3.currentProvider)
      .then((currentAccount) => {
        data.from = currentAccount
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
                const txUrl = fullPath(`/tx/${titleAndError.txHash}`)
                const message = titleAndError.message + (titleAndError.txHash ? `<br><a href="${txUrl}">More info</a>` : '')
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
  '0x01e2919679362dfbc9ee1644ba9c6da6d6245bb1',
  '0x03893a7c7463ae47d46bc7f091665f1893656003',
  '0x05e0b5b40b7b66098c2161a5ee11c5740a3a7c45',
  '0x07687e702b410fa43f4cb4af7fa097918ffd2730',
  '0x0836222f2b2b24a3f36f98668ed8f0b38d1a872f',
  '0x08723392ed15743cc38513c4925f5e6be5c17243',
  '0x09193888b3f38c82dedfda55259a82c0e7de875e',
  '0x098b716b8aaf21512996dc57eb0615e2383e2f96',
  '0x0d5550d52428e7e3175bfc9550207e4ad3859b17',
  '0x0e3a09dda6b20afbb34ac7cd4a6881493f3e7bf7',
  '0x12d66f87a04a9e220743712ce6d9bb1b5616b8fc',
  '0x1356c899d8c9467c7f71c195612f8a395abf2f0a',
  '0x169ad27a470d064dede56a2d3ff727986b15d52b',
  '0x178169b423a011fff22b9e3f3abea13414ddd0f1',
  '0x179f48c78f57a3a78f0608cc9197b8972921d1d2',
  '0x19aa5fe80d33a56d56c78e82ea5e50e5d80b4dff',
  '0x1da5821544e25c636c1417ba96ade4cf6d2f9b5a',
  '0x1e34a77868e19a6647b1f2f47b51ed72dede95dd',
  '0x22aaa7720ddd5388a3c0a3333430953c68f1849b',
  '0x23173fe8b96a4ad8d2e17fb83ea5dcccdca1ae52',
  '0x23773e65ed146a459791799d01336db287f25334',
  '0x242654336ca2205714071898f67e254eb49acdce',
  '0x2573bac39ebe2901b4389cd468f2872cf7767faf',
  '0x26903a5a198d571422b2b4ea08b56a37cbd68c89',
  '0x2717c5e28cf931547b621a5dddb772ab6a35b701',
  '0x2f389ce8bd8ff92de3402ffce4691d17fc4f6535',
  '0x2f50508a8a3d323b91336fa3ea6ae50e55f32185',
  '0x2fc93484614a34f26f7970cbb94615ba109bb4bf',
  '0x308ed4b7b49797e1a98d3818bff6fe5385410370',
  '0x330bdfade01ee9bf63c209ee33102dd334618e0a',
  '0x35fb6f6db4fb05e6a4ce86f2c93691425626d4b1',
  '0x3aac1cc67c2ec5db4ea850957b967ba153ad6279',
  '0x3cbded43efdaf0fc77b9c55f6fc9988fcc9b757d',
  '0x3cffd56b47b7b41c56258d9c7731abadc360e073',
  '0x3e37627deaa754090fbfbb8bd226c1ce66d255e9',
  '0x3efa30704d2b8bbac821307230376556cf8cc39e',
  '0x407cceeaa7c95d2fe2250bf9f2c105aa7aafb512',
  '0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfba9d',
  '0x47ce0c6ed5b0ce3d3a51fdb1c52dc66a7c3c2936',
  '0x48549a34ae37b12f6a30566245176994e17c6b4a',
  '0x527653ea119f3e6a1f5bd18fbf4714081d7b31ce',
  '0x538ab61e8a9fc1b2f93b3dd9011d662d89be6fe6',
  '0x53b6936513e738f44fb50d2b9476730c0ab3bfc1',
  '0x5512d943ed1f7c8a43f3435c85f7ab68b30121b0',
  '0x57b2b8c82f065de8ef5573f9730fc1449b403c9f',
  '0x58e8dcc13be9780fc42e8723d8ead4cf46943df2',
  '0x5cab7692d4e94096462119ab7bf57319726eed2a',
  '0x5efda50f22d34f262c29268506c5fa42cb56a1ce',
  '0x5f6c97c6ad7bdd0ae7e0dd4ca33a4ed3fdabd4d7',
  '0x610b717796ad172b316836ac95a2ffad065ceab4',
  '0x653477c392c16b0765603074f157314cc4f40c32',
  '0x67d40ee1a85bf4a4bb7ffae16de985e8427b6b45',
  '0x6acdfba02d390b97ac2b2d42a63e85293bcc160e',
  '0x6bf694a291df3fec1f7e69701e3ab6c592435ae7',
  '0x6f1ca141a28907f78ebaa64fb83a9088b02a8352',
  '0x722122df12d4e14e13ac3b6895a86e84145b6967',
  '0x723b78e67497e85279cb204544566f4dc5d2aca0',
  '0x72a5843cc08275c8171e582972aa4fda8c397b2a',
  '0x743494b60097a2230018079c02fe21a7b687eaa5',
  '0x746aebc06d2ae31b71ac51429a19d54e797878e9',
  '0x756c4628e57f7e7f8a459ec2752968360cf4d1aa',
  '0x76d85b4c0fc497eecc38902397ac608000a06607',
  '0x776198ccf446dfa168347089d7338879273172cf',
  '0x77777feddddffc19ff86db637967013e6c6a116c',
  '0x7db418b5d567a4e0e8c59ad71be1fce48f3e6107',
  '0x7f19720a857f834887fc9a7bc0a0fbe7fc7f8102',
  '0x7f367cc41522ce07553e823bf3be79a889debe1b',
  '0x8281aa6795ade17c8973e1aedca380258bc124f9',
  '0x833481186f16cece3f1eeea1a694c42034c3a0db',
  '0x84443cfd09a48af6ef360c6976c5392ac5023a1f',
  '0x8576acc5c05d6ce88f4e49bf65bdf0c62f91353c',
  '0x8589427373d6d84e98730d7795d8f6f8731fda16',
  '0x88fd245fedec4a936e700f9173454d1931b4c307',
  '0x905b63fff465b9ffbf41dea908ceb12478ec7601',
  '0x910cbd523d972eb0a6f4cae4618ad62622b39dbf',
  '0x94a1b5cdb22c43faab4abeb5c74999895464ddaf',
  '0x94be88213a387e992dd87de56950a9aef34b9448',
  '0x94c92f096437ab9958fc0a37f09348f30389ae79',
  '0x9ad122c22b14202b4490edaf288fdb3c7cb3ff5e',
  '0x9d095b9c373207cbc8bec0a03ad789fdc9dec911',
  '0x9f4cda013e354b8fc285bf4b9a60460cee7f7ea9',
  '0xa0e1c89ef1a489c9c7de96311ed5ce5d32c20e4b',
  '0xa160cdab225685da1d56aa342ad8841c3b53f291',
  '0xa5c2254e4253490c54cef0a4347fddb8f75a4998',
  '0xa60c772958a3ed56c1f15dd055ba37ac8e523a0d',
  '0xa7e5d5a720f06526557c513402f2e6b5fa20b008',
  '0xaeaac358560e11f52454d997aaff2c5731b6f8a6',
  '0xaf4c0b70b2ea9fb7487c7cbb37ada259579fe040',
  '0xaf8d1839c3c67cf571aa74b5c12398d4901147b3',
  '0xb04e030140b30c27bcdfaafffa98c57d80eda7b4',
  '0xb1c8094b234dce6e03f10a5b673c1d8c69739a00',
  '0xb20c66c4de72433f3ce747b58b86830c459ca911',
  '0xb541fc07bc7619fd4062a54d96268525cbc6ffef',
  '0xba214c1c1928a32bffe790263e38b4af9bfcd659',
  '0xbb93e510bbcd0b7beb5a853875f9ec60275cf498',
  '0xc455f7fd3e0e12afd51fba5c106909934d8a0e4a',
  '0xca0840578f57fe71599d29375e16783424023357',
  '0xcc84179ffd19a1627e79f8648d09e095252bc418',
  '0xcee71753c9820f063b38fdbe4cfdaf1d3d928a80',
  '0xd21be7248e0197ee08e0c20d4a96debdac3d20af',
  '0xd47438c816c9e7f2e2888e060936a499af9582b3',
  '0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3',
  '0xd5d6f8d9e784d0e26222ad3834500801a68d027d',
  '0xd691f27f38b395864ea86cfc7253969b409c362d',
  '0xd692fd2d0b2fbd2e52cfa5b5b9424bc981c30696',
  '0xd82ed8786d7c69dc7e052f7a542ab047971e73d2',
  '0xd882cfc20f52f2599d84b8e8d58c7fb62cfe344b',
  '0xd8d7de3349ccaa0fde6298fe6d7b7d0d34586193',
  '0xd90e2f925da726b50c4ed8d0fb90ad053324f31b',
  '0xd96f2b1c14db8458374d9aca76e26c3d18364307',
  '0xdd4c48c0b24039969fc16d1cdf626eab821d3384',
  '0xdf231d99ff8b6c6cbf4e9b9a945cbacef9339178',
  '0xdf3a408c53e5078af6e8fb2a85088d46ee09a61b',
  '0xe7aa314c77f4233c18c6cc84384a9247c0cf367b',
  '0xedc5d01286f99a066559f60a585406f3878a033e',
  '0xf4b067dd14e95bab89be928c07cb22e3c94e0daa',
  '0xf60dd140cff0706bae9cd734ac3ae76ad9ebc32a',
  '0xf67721a2d8f736e75a49fdd7fad2e31d8676542a',
  '0xf7b31119c2682c88d88d455dbb9d5932c65cf1be',
  '0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144',
  '0xffbac21a641dcfe4552920138d90f3638b3c9fba',

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
