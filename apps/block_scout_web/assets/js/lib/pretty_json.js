import $ from 'jquery'

function prettyPrint (element) {
  let jsonString = element.dataset.json
  let pretty = JSON.stringify(JSON.parse(jsonString), undefined, 2)
  element.innerHTML = pretty
}

$('[data-json]').each((_index, element) => prettyPrint(element))
