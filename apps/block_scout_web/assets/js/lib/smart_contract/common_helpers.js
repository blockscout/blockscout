import $ from 'jquery'

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
    let sanitizedInputValue
    sanitizedInputValue = replaceSpaces(inputValue, inputType)
    sanitizedInputValue = replaceDoubleQuotes(sanitizedInputValue, inputType)

    if (isArrayInputType(inputType) || isTupleInputType(inputType)) {
      if (sanitizedInputValue === '') {
        return [[]]
      } else {
        if (sanitizedInputValue.startsWith('[') && sanitizedInputValue.endsWith(']')) {
          sanitizedInputValue = sanitizedInputValue.substring(1, sanitizedInputValue.length - 1)
        }
        const inputValueElements = sanitizedInputValue.split(',')
        const sanitizedInputValueElements = inputValueElements.map(elementValue => {
          const elementInputType = inputType.split('[')[0]
          return replaceDoubleQuotes(elementValue, elementInputType)
        })
        return [sanitizedInputValueElements]
      }
    } else { return sanitizedInputValue }
  })
}

function isArrayInputType (inputType) {
  return inputType && inputType.includes('[') && inputType.includes(']')
}

function isTupleInputType (inputType) {
  return inputType.includes('tuple') && !isArrayInputType(inputType)
}

function isAddressInputType (inputType) {
  return inputType.includes('address') && !isArrayInputType(inputType)
}

function isUintInputType (inputType) {
  return inputType.includes('int') && !isArrayInputType(inputType)
}

function isStringInputType (inputType) {
  return inputType.includes('string') && !isArrayInputType(inputType)
}

function isNonSpaceInputType (inputType) {
  return isAddressInputType(inputType) || inputType.includes('int') || inputType.includes('bool')
}

function replaceSpaces (value, type) {
  if (isNonSpaceInputType(type)) {
    return value.replace(/\s/g, '')
  } else {
    return value
  }
}

function replaceDoubleQuotes (value, type) {
  if (isAddressInputType(type) || isUintInputType(type) || isStringInputType(type)) {
    if (typeof value.replaceAll === 'function') {
      return value.replaceAll('"', '')
    } else {
      return value.replace(/"/g, '')
    }
  } else {
    return value
  }
}
