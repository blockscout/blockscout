import Web3 from 'web3'
import $ from 'jquery'
import { props } from 'eth-net-props'

const connectSelector = '[connect-wallet]'
const connectToSelector = '[connect-to]'
const connectedToSelector = '[connected-to]'
const disconnectSelector = '[disconnect-wallet]'

export function getContractABI ($form) {
  const implementationAbi = $form.data('implementation-abi')
  const parentAbi = $form.data('contract-abi')
  const $parent = $('[data-smart-contract-functions]')
  const contractType = $parent.data('type')
  const contractAbi = contractType === 'proxy' ? implementationAbi : parentAbi
  return contractAbi
}

export function getMethodInputs (contractAbi, functionName) {
  const functionAbi = contractAbi.find(abi =>
    abi.name === functionName
  )
  return functionAbi && functionAbi.inputs
}

export function prepareMethodArgs ($functionInputs, inputs) {
  return $.map($functionInputs, (element, ind) => {
    const inputValue = $(element).val()
    const inputType = inputs[ind] && inputs[ind].type
    const inputComponents = inputs[ind] && inputs[ind].components
    let sanitizedInputValue
    sanitizedInputValue = replaceDoubleQuotes(inputValue, inputType, inputComponents)
    sanitizedInputValue = replaceSpaces(sanitizedInputValue, inputType, inputComponents)

    if (isArrayInputType(inputType) || isTupleInputType(inputType)) {
      if (sanitizedInputValue === '' || sanitizedInputValue === '[]') {
        return [[]]
      } else {
        if (sanitizedInputValue.startsWith('[') && sanitizedInputValue.endsWith(']')) {
          sanitizedInputValue = sanitizedInputValue.substring(1, sanitizedInputValue.length - 1)
        }
        const inputValueElements = sanitizedInputValue.split(',')
        const sanitizedInputValueElements = inputValueElements.map(elementValue => {
          const elementInputType = inputType.split('[')[0]

          let sanitizedElementValue = replaceDoubleQuotes(elementValue, elementInputType)
          sanitizedElementValue = replaceSpaces(sanitizedElementValue, elementInputType)

          if (isBoolInputType(elementInputType)) {
            sanitizedElementValue = convertToBool(elementValue)
          }
          return sanitizedElementValue
        })
        return [sanitizedInputValueElements]
      }
    } else if (isBoolInputType(inputType)) {
      return convertToBool(sanitizedInputValue)
    } else { return sanitizedInputValue }
  })
}

export function compareChainIDs (explorerChainId, walletChainIdHex) {
  if (explorerChainId !== parseInt(walletChainIdHex)) {
    const networkDisplayNameFromWallet = props.getNetworkDisplayName(walletChainIdHex)
    const networkDisplayName = props.getNetworkDisplayName(explorerChainId)
    const errorMsg = `You connected to ${networkDisplayNameFromWallet} chain in the wallet, but the current instance of Blockscout is for ${networkDisplayName} chain`
    return Promise.reject(new Error(errorMsg))
  } else {
    return Promise.resolve()
  }
}

export const formatError = (error) => {
  let { message } = error
  message = message && message.split('Error: ').length > 1 ? message.split('Error: ')[1] : message
  return message
}

export const formatTitleAndError = (error) => {
  let { message } = error
  let title = message && message.split('Error: ').length > 1 ? message.split('Error: ')[1] : message
  title = title && title.split('{').length > 1 ? title.split('{')[0].replace(':', '') : title
  let txHash = ''
  let errorMap = ''
  try {
    errorMap = message && message.indexOf('{') >= 0 ? JSON.parse(message && message.slice(message.indexOf('{'))) : ''
    message = errorMap.error || ''
    txHash = errorMap.transactionHash || ''
  } catch (exception) {
    message = ''
  }
  return { title: title, message: message, txHash: txHash }
}

export const getCurrentAccountPromise = (provider) => {
  return new Promise((resolve, reject) => {
    if (provider && provider.wc) {
      getCurrentAccountFromWCPromise(provider)
        .then(account => resolve(account))
        .catch(err => {
          reject(err)
        })
    } else {
      getCurrentAccountFromMMPromise()
        .then(account => resolve(account))
        .catch(err => {
          reject(err)
        })
    }
  })
}

export const getCurrentAccountFromWCPromise = (provider) => {
  return new Promise((resolve, reject) => {
  // Get a Web3 instance for the wallet
    const web3 = new Web3(provider)

    // Get list of accounts of the connected wallet
    web3.eth.getAccounts()
      .then(accounts => {
        // MetaMask does not give you all accounts, only the selected account
        resolve(accounts[0])
      })
      .catch(err => {
        reject(err)
      })
  })
}

export const getCurrentAccountFromMMPromise = () => {
  return new Promise((resolve, reject) => {
    window.ethereum.request({ method: 'eth_accounts' })
      .then(accounts => {
        const account = accounts[0] ? accounts[0].toLowerCase() : null
        resolve(account)
      })
      .catch(err => {
        reject(err)
      })
  })
}

export function showConnectedToElements (account, provider) {
  document.querySelector(connectToSelector) && document.querySelector(connectToSelector).classList.add('hidden')
  document.querySelector(connectSelector) && document.querySelector(connectSelector).classList.remove('hidden')
  document.querySelector(connectedToSelector) && document.querySelector(connectedToSelector).classList.remove('hidden')
  // Show disconnect button only in case of Wallet Connect
  if (provider && provider.wc) {
    document.querySelector(disconnectSelector) && document.querySelector(disconnectSelector).classList.remove('hidden')
  } else {
    document.querySelector(disconnectSelector) && document.querySelector(disconnectSelector).classList.add('hidden')
  }
  setConnectToAddress(account)
}

export function showConnectElements () {
  document.querySelector(connectToSelector) && document.querySelector(connectToSelector).classList.remove('hidden')
  document.querySelector(connectSelector) && document.querySelector(connectSelector).classList.remove('hidden')
  document.querySelector(connectedToSelector) && document.querySelector(connectedToSelector).classList.add('hidden')
}

export function hideConnectButton () {
  document.querySelector(connectToSelector) && document.querySelector(connectToSelector).classList.remove('hidden')
  document.querySelector(connectSelector) && document.querySelector(connectSelector).classList.add('hidden')
  document.querySelector(connectedToSelector) && document.querySelector(connectedToSelector).classList.add('hidden')
}

function setConnectToAddress (account) {
  if (document.querySelector('[connected-to-address]')) {
    document.querySelector('[connected-to-address]').innerHTML = `<a href='/address/${account}'>${account}</a>`
  }
}

function convertToBool (value) {
  const boolVal = (value === 'true' || value === '1' || value === 1)

  return boolVal
}

function isArrayInputType (inputType) {
  return inputType && inputType.includes('[') && inputType.includes(']')
}

function isTupleInputType (inputType) {
  return inputType && inputType.includes('tuple') && !isArrayInputType(inputType)
}

function isAddressInputType (inputType) {
  return inputType && inputType.includes('address') && !isArrayInputType(inputType)
}

function isUintInputType (inputType) {
  return inputType && inputType.includes('int') && !isArrayInputType(inputType)
}

function isStringInputType (inputType) {
  return inputType && inputType.includes('string') && !isArrayInputType(inputType)
}

function isBoolInputType (inputType) {
  return inputType && inputType.includes('bool') && !isArrayInputType(inputType)
}

function isNonSpaceInputType (inputType) {
  return isAddressInputType(inputType) || inputType.includes('int') || inputType.includes('bool')
}

function replaceSpaces (value, type, components) {
  if (isNonSpaceInputType(type)) {
    return value.replace(/\s/g, '')
  } else if (isTupleInputType(type)) {
    return value
      .split(',')
      .map((itemValue, itemIndex) => {
        const itemType = components && components[itemIndex] && components[itemIndex].type

        return replaceSpaces(itemValue, itemType)
      })
      .join(',')
  } else {
    return value.trim()
  }
}

function replaceDoubleQuotes (value, type, components) {
  if (isAddressInputType(type) || isUintInputType(type) || isStringInputType(type)) {
    if (typeof value.replaceAll === 'function') {
      return value.replaceAll('"', '')
    } else {
      return value.replace(/"/g, '')
    }
  } else if (isTupleInputType(type)) {
    return value
      .split(',')
      .map((itemValue, itemIndex) => {
        const itemType = components && components[itemIndex] && components[itemIndex].type

        return replaceDoubleQuotes(itemValue, itemType)
      })
      .join(',')
  } else {
    return value
  }
}
