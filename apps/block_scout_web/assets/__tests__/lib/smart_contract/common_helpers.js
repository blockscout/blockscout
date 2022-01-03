/**
 * @jest-environment jsdom
 */

import { prepareMethodArgs } from '../../../js/lib/smart_contract/common_helpers'
import $ from 'jquery'
  
const oneFieldHTML =
    '<form data-function-form>' +
    ' <input type="hidden" name="function_name" value="convertMultiple">' + 
    ' <input type="hidden" name="method_id" value="">' + 
    ' <div>' + 
    '   <input type="text" name="function_input" id="first">' + 
    ' </div>' + 
    ' <input type="submit" value="Write">' + 
    '</form>'

const twoFieldHTML =
    '<form data-function-form>' +
    ' <input type="hidden" name="function_name" value="convertMultiple">' + 
    ' <input type="hidden" name="method_id" value="">' + 
    ' <div>' + 
    '   <input type="text" name="function_input" id="first">' + 
    ' </div>' + 
    ' <div>' + 
    '   <input type="text" name="function_input" id="second">' + 
    ' </div>' + 
    ' <input type="submit" value="Write">' + 
    '</form>'

test('prepare contract args | type: address[]*2', () => {
    document.body.innerHTML = twoFieldHTML

    var inputs = [
        {
            "type": "address[]",
            "name": "arg1",
            "internalType": "address[]"
        },
        {
            "type": "address[]",
            "name": "arg2",
            "internalType": "address[]"
        }
    ]

    document.getElementById('first').value = '  0x0000000000000000000000000000000000000000  ,     0x0000000000000000000000000000000000000001   '
    document.getElementById('second').value = ' 0x0000000000000000000000000000000000000002  ,     0x0000000000000000000000000000000000000003   '
    const expectedValue = [
        [
          '0x0000000000000000000000000000000000000000',
          '0x0000000000000000000000000000000000000001'
        ],
        [
          '0x0000000000000000000000000000000000000002',
          '0x0000000000000000000000000000000000000003'
        ]
      ]
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: address', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "address",
            "name": "arg1",
            "internalType": "address"
        }
    ]

    document.getElementById('first').value = ' 0x000000000000000000 0000000000000000000000 '
    const expectedValue = ['0x0000000000000000000000000000000000000000']
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: string', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "string",
            "name": "arg1",
            "internalType": "string"
        }
    ]

    document.getElementById('first').value = '  0x0000000000000000000000000000000000000000  , 0x0000000000000000000000000000000000000001   '
    const expectedValue = ['0x0000000000000000000000000000000000000000  , 0x0000000000000000000000000000000000000001']
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: string[]', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "string[]",
            "name": "arg1",
            "internalType": "string[]"
        }
    ]

    document.getElementById('first').value = ' "  0x0000000000000000000000000000000000000000 " , "    0x0000000000000000000000000000000000000001   " '
    const expectedValue = [['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000001']]
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: bool[]', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "bool[]",
            "name": "arg1",
            "internalType": "bool[]"
        }
    ]

    document.getElementById('first').value = ' true , false '
    const expectedValue = [[true, false]]
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: bool', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "bool",
            "name": "arg1",
            "internalType": "bool"
        }
    ]

    document.getElementById('first').value = ' fals e '
    const expectedValue = [false]
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})


test('prepare contract args | type: uint256', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "uint256",
            "name": "arg1",
            "internalType": "uint256"
        }
    ]

    document.getElementById('first').value = ' 9 876 543 210 '
    const expectedValue = ['9876543210']
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})

test('prepare contract args | type: uint256[]', () => {
    document.body.innerHTML = oneFieldHTML

    var inputs = [
        {
            "type": "uint256[]",
            "name": "arg1",
            "internalType": "uint256[]"
        }
    ]

    document.getElementById('first').value = ' 156 000 , 10 690 000 , 59874 '
    const expectedValue = [['156000', '10690000', '59874']]
    const $functionInputs = $('[data-function-form]').find('input[name=function_input]')
    expect(prepareMethodArgs($functionInputs, inputs)).toEqual(expectedValue)
})