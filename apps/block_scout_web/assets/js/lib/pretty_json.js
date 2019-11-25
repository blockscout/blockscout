import $ from 'jquery'

function prettyPrint (element) {
  const jsonString = element.dataset.json
  const pretty = JSON.stringify(JSON.parse(jsonString), undefined, 2)
  element.innerHTML = pretty
}

$('[data-json]').each((_index, element) => prettyPrint(element))
