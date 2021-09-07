import identicon from 'identicon'

function getTokenIconUrl (chainID, addressHash) {
  var chainName = null
  switch (chainID) {
    case '1':
      chainName = 'ethereum'
      break
    case '99':
      chainName = 'poa'
      break
    case '100':
      chainName = 'xdai'
      break
    default:
      chainName = null
      break
  }
  if (chainName) {
    return `https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/${chainName}/assets/${addressHash}/logo.png`
  } else {
    return null
  }
}

function appendTokenIcon ($tokenIconContainer, chainID, addressHash, foreignChainID, foreignAddressHash, displayTokenIcons) {
  var tokenIconURL = null
  if (chainID) {
    tokenIconURL = getTokenIconUrl(chainID.toString(), addressHash)
  } else if (foreignChainID) {
    tokenIconURL = getTokenIconUrl(foreignChainID.toString(), foreignAddressHash)
  }
  if (displayTokenIcons) {
    checkLink(tokenIconURL)
      .then(checkTokenIconLink => {
        if (checkTokenIconLink) {
          if ($tokenIconContainer) {
            var img = new Image(20, 20)
            img.src = tokenIconURL
            $tokenIconContainer.append(img)
          }
        } else {
          identicon.generate({ id: addressHash, size: 20 }, function (err, buffer) {
            if (err) throw err

            var img = new Image()
            img.src = buffer
            if ($tokenIconContainer) {
              $tokenIconContainer.append(img)
            }
          })
        }
      })
  }
}

async function checkLink (url) {
  if (url) {
    try {
      const res = await fetch(url)
      return res.ok
    } catch (_error) {
      return false
    }
  } else {
    return false
  }
}

export { appendTokenIcon, checkLink, getTokenIconUrl }
