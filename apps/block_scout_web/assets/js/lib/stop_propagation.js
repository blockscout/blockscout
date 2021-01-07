import $ from 'jquery'

$('[data-selector="stop-propagation"]').on("click", (event) => event.stopPropagation())
