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
    const inputComponents = inputs[ind] && inputs[ind].components
    let sanitizedInputValue
    sanitizedInputValue = replaceSpaces(inputValue, inputType, inputComponents)
    sanitizedInputValue = replaceDoubleQuotes(sanitizedInputValue, inputType, inputComponents)

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

          var sanitizedElementValue = replaceDoubleQuotes(elementValue, elementInputType)

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
    return value
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
