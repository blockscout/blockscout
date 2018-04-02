import jasmineRequire from 'jasmine-core/lib/jasmine-core/jasmine'
global.jasmineRequire = jasmineRequire
require('jasmine-core/lib/jasmine-core/jasmine-html')
require('jasmine-core/lib/jasmine-core/boot')

window.require.list().forEach(function (module) {
  if (module.indexOf("_spec.js") !== -1) require(module)
})
