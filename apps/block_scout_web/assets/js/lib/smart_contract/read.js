import $ from 'jquery'
import { getCurrentAccountPromise } from './common_helpers'

export const queryMethod = (isWalletEnabled, url, $methodId, args, type, functionName, $responseContainer) => {
  let data = {
    function_name: functionName,
    method_id: $methodId.val(),
    type: type,
    args
  }
  if (isWalletEnabled) {
    getCurrentAccountPromise(window.web3 && window.web3.currentProvider)
      .then((currentAccount) => {
        data = {
          function_name: functionName,
          method_id: $methodId.val(),
          type: type,
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
