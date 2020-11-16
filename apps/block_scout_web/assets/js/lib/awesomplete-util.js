/* eslint-env browser */
/* global Awesomplete */
/* exported AwesompleteUtil */

/*
 * Library endorsing Lea Verou's Awesomplete widget, providing:
 * - dynamic remote data loading
 * - labels with HTML markup
 * - events and styling for exact matches
 * - events and styling for mismatches
 * - select item when TAB key is used
 *
 * (c) Nico Hoogervorst
 * License: MIT
 *
 */
window.AwesompleteUtil = (function () {
  //
  // event names and css classes
  //
  var _AWE = 'awesomplete-'
  var _AWE_LOAD = _AWE + 'loadcomplete'
  var _AWE_CLOSE = _AWE + 'close'
  var _AWE_MATCH = _AWE + 'match'
  var _AWE_PREPOP = _AWE + 'prepop'
  var _AWE_SELECT = _AWE + 'select'
  var _CLS_FOUND = 'awe-found'
  var _CLS_NOT_FOUND = 'awe-not-found'
  var $ = Awesomplete.$ /* shortcut for document.querySelector */

  //
  // private functions
  //

  // Some parts are shamelessly copied from Awesomplete.js like the logic inside this _suggestion function.
  // Returns an object with label and value properties. Data parameter is plain text or Object/Array with label and value.
  function _suggestion (data) {
    var lv = Array.isArray(data)
      ? { label: data[0], value: data[1] }
      : typeof data === 'object' && 'label' in data && 'value' in data ? data : { label: data, value: data }
    return { label: lv.label || lv.value, value: lv.value }
  }

  // Helper to send events with detail property.
  function _fire (target, name, detail) {
    // $.fire uses deprecated methods but other methods don't work in IE11.
    return $.fire(target, name, { detail: detail })
  }

  // Look if there is an exact match or a mismatch, set awe-found, awe-not-found css class and send match events.
  function _matchValue (awe, prepop) {
    var input = awe.input /* the input field */
    var classList = input.classList
    var utilprops = awe.utilprops /* extra properties piggybacked on Awesomplete object */
    var selected = utilprops.selected /* the exact selected Suggestion with label and value */
    var val = utilprops.convertInput.call(awe, input.value) /* trimmed lowercased value */
    var opened = awe.opened /* is the suggestion list opened? */
    var result = [] /* matches with value */
    var list = awe._list /* current list of suggestions */
    var suggestion, fake, rec, j /* function scoped variables */
    utilprops.prepop = false /* after the first call it's not a prepopulation phase anymore */
    if (list) { /* if there is a suggestion list */
      for (j = 0; j < list.length; j++) { /* loop all suggestions */
        rec = list[j]
        suggestion = _suggestion(awe.data(rec, val)) /* call data convert function */
        // with maxItems = 0 cannot look if suggestion list is opened to determine if there are still matches,
        // instead call the filter method to see if there are still some options.
        if (awe.maxItems === 0) {
          // Awesomplete.FILTER_CONTAINS and Awesomplete.FILTER_STARTSWITH use the toString method.
          suggestion.toString = function () { return '' + this.label }
          if (awe.filter(suggestion, val)) {
            // filter returns true, so there is at least one partial match.
            opened = true
          }
        }
        // Don't want to change the real input field, emulate a fake one.
        fake = { input: { value: '' } }
        // Determine how this suggestion would look like if it is replaced in the input field,
        // it is an exact match if somebody types exactly that.
        // Use the fake input here. fake.input.value will contain the result of the replace function.
        awe.replace.call(fake, suggestion)
        // Trim and lowercase also the fake input and compare that with the currently typed-in value.
        if (utilprops.convertInput.call(awe, fake.input.value) === val) {
          // This is an exact match. However there might more suggestions with the same value.
          // If the user selected a suggestion from the list, check if this one matches, assuming that
          // value + label is unique (if not it will be difficult for the user to make an informed decision).
          if (selected && selected.value === suggestion.value && selected.label === suggestion.label) {
            // this surely is the selected one
            result = [rec]
            break
          }
          // add the matching record to the result set.
          result.push(rec)
        } // end if
      } // end loop

      // if the result differs from the previous result
      if (utilprops.prevSelected !== result) {
        // if there is an exact match
        if (result.length > 0) {
          // if prepopulation phase (initial/autofill value); not triggered by user input
          if (prepop) {
            _fire(input, _AWE_PREPOP, result)
          } else if (utilprops.changed) { /* if input is changed */
            utilprops.prevSelected = result /* new result      */
            classList.remove(_CLS_NOT_FOUND) /* remove class   */
            classList.add(_CLS_FOUND) /* add css class */
            _fire(input, _AWE_MATCH, result) /* fire event   */
          }
        } else if (prepop) { /* no exact match, if in prepopulation phase */
          _fire(input, _AWE_PREPOP, [])
        } else if (utilprops.changed) { /* no exact match, if input is changed */
          utilprops.prevSelected = []
          classList.remove(_CLS_FOUND)
          // Mark as not-found if there are no suggestions anymore or if another field is now active
          if (!opened || (input !== document.activeElement)) {
            if (val.length > 0) {
              classList.add(_CLS_NOT_FOUND)
              _fire(input, _AWE_MATCH, [])
            }
          } else {
            classList.remove(_CLS_NOT_FOUND)
          }
        }
      }
    }
  }

  // Listen to certain events of THIS awesomplete object to trigger input validation.
  function _match (ev) {
    var awe = this
    if ((ev.type === _AWE_CLOSE || ev.type === _AWE_LOAD || ev.type === 'blur') && ev.target === awe.input) {
      _matchValue(awe, awe.utilprops.prepop && ev.type === _AWE_LOAD)
    }
  }

  // Select currently selected item if tab or shift-tab key is used.
  function _onKeydown (ev) {
    var awe = this
    if (ev.target === awe.input && ev.keyCode === 9) { // TAB key
      awe.select() // take current selected item
    }
  }

  // Handle selection event. State changes when an item is selected.
  function _select (ev) {
    var awe = this
    awe.utilprops.changed = true // yes, user made a change
    awe.utilprops.selected = ev.text // Suggestion object
    const address = ev.text.split(/<p>/)[0]
    window.open(`/search?q=${address}`, '_self')
  }

  // check if the object is empty {} object
  function _isEmpty (val) {
    return Object.keys(val).length === 0 && val.constructor === Object
  }

  // Need an updated suggestion list if:
  // - There is no result yet, or there is a result but not for the characters we entered
  // - or there might be more specific results because the limit was reached.
  function _ifNeedListUpdate (awe, val, queryVal) {
    var utilprops = awe.utilprops
    return (!utilprops.listQuery ||
                  (!utilprops.loadall && /* with loadall, if there is a result, there is no need for new lists */
                   val.lastIndexOf(queryVal, 0) === 0 &&
                   (val.lastIndexOf(utilprops.listQuery, 0) !== 0 ||
                     (typeof utilprops.limit === 'number' && awe._list.length >= utilprops.limit))))
  }

  // Set a new suggestion list. Trigger loadcomplete event.
  function _loadComplete (awe, list, queryVal) {
    awe.list = list
    awe.utilprops.listQuery = queryVal
    _fire(awe.input, _AWE_LOAD, queryVal)
  }

  // Handle ajax response. Expects HTTP OK (200) response with JSON object with suggestion(s) (array).
  function _onLoad () {
    var t = this
    var awe = t.awe
    var xhr = t.xhr
    var queryVal = t.queryVal
    var val = awe.utilprops.val
    var data
    var prop
    if (xhr.status === 200) {
      data = JSON.parse(xhr.responseText)
      if (awe.utilprops.convertResponse) data = awe.utilprops.convertResponse(data)
      if (!Array.isArray(data)) {
        if (awe.utilprops.limit === 0 || awe.utilprops.limit === 1) {
          // if there is max 1 result expected, the array is not needed.
          // Fur further processing, take the whole result and put it as one element in an array.
          data = _isEmpty(data) ? [] : [data]
        } else {
          // search for the first property that contains an array
          for (prop in data) {
            if (Array.isArray(data[prop])) {
              data = data[prop]
              break
            }
          }
        }
      }
      // can only handle arrays
      if (Array.isArray(data)) {
        // are we still interested in this response?
        if (_ifNeedListUpdate(awe, val, queryVal)) {
          // accept the new suggestion list
          _loadComplete(awe, data, queryVal || awe.utilprops.loadall)
        }
      }
    }
  }

  // Perform suggestion list lookup for the current value and validate. Use ajax when there is an url specified.
  function _lookup (awe, val) {
    var xhr
    if (awe.utilprops.url) {
      // are we still interested in this response?
      if (_ifNeedListUpdate(awe, val, val)) {
        xhr = new XMLHttpRequest()
        awe.utilprops.ajax.call(awe,
          awe.utilprops.url,
          awe.utilprops.urlEnd,
          awe.utilprops.loadall ? '' : val,
          _onLoad.bind({ awe: awe, xhr: xhr, queryVal: val }),
          xhr
        )
      } else {
        _matchValue(awe, awe.utilprops.prepop)
      }
    } else {
      _matchValue(awe, awe.utilprops.prepop)
    }
  }

  // Restart autocomplete search: clear css classes and send match-event with empty list.
  function _restart (awe) {
    var elem = awe.input
    var classList = elem.classList
    // IE11 only handles the first parameter of the remove method.
    classList.remove(_CLS_NOT_FOUND)
    classList.remove(_CLS_FOUND)
    _fire(elem, _AWE_MATCH, [])
  }

  // handle new input value
  function _update (awe, val, prepop) {
    // prepop parameter is optional. Default value is false.
    awe.utilprops.prepop = prepop || false
    // if value changed
    if (awe.utilprops.val !== val) {
      // new value, clear previous selection
      awe.utilprops.selected = null
      // yes, user made a change
      awe.utilprops.changed = true
      awe.utilprops.val = val
      // value is empty or smaller than minChars
      if (val.length < awe.minChars || val.length === 0) {
        // restart autocomplete search
        _restart(awe)
      }
      if (val.length >= awe.minChars) {
        // lookup suggestions and validate input
        _lookup(awe, val)
      }
    }
    return awe
  }

  // handle input changed event for THIS awesomplete object
  function _onInput (e) {
    var awe = this
    var val
    if (e.target === awe.input) {
      // lowercase and trim input value
      val = awe.utilprops.convertInput.call(awe, awe.input.value)
      _update(awe, val)
    }
  }

  // item function (as specified in Awesomplete) which just creates the 'li' HTML tag.
  function _item (html /* , input */) {
    return $.create('li', {
      innerHTML: html,
      'aria-selected': 'false'
    })
  }

  // Escape HTML characters in text.
  function _htmlEscape (text) {
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
  }

  // Function to copy a field from the selected autocomplete item to another DOM element.
  function _copyFun (e) {
    var t = this
    var sourceId = t.sourceId
    var dataField = t.dataField
    var targetId = t.targetId
    var elem
    var val
    if (e.target === $(sourceId)) {
      if (typeof targetId === 'function') {
        targetId(e, dataField)
      } else {
        // lookup target element if it isn't resolved yet
        elem = $(targetId)
        // don't override target inputs if user is currently editing it.
        if (elem && elem !== document.activeElement) {
          // event must contain 1 item from suggestion list
          val = Array.isArray(e.detail) && e.detail.length === 1 ? e.detail[0] : null
          // if a datafield is specified, take that value
          val = (dataField && val ? val[dataField] : val) || ''
          // if it is an input control
          if (typeof elem.value !== 'undefined') {
            // set new value
            elem.value = val
            // not really sure if it is an input control, check if it has a classList
            if (elem.classList && elem.classList.remove) {
              // it might be another awesomplete control, if so the input is not wrong anymore because it's changed now
              elem.classList.remove(_CLS_NOT_FOUND)
            }
          } else if (typeof elem.src !== 'undefined') { /* is it an image tag? */
            elem.src = val
          } else {
            // use innerHTML to set the new value, because value might intentionally contain HTML markup
            elem.innerHTML = val
          }
        }
      }
    }
  }

  // click function for the combobox button
  function _clickFun (e) {
    var t = this
    var awe
    var minChars
    if (e.target === $(t.btnId)) {
      e.preventDefault()
      awe = t.awe
      // toggle open/close
      if (awe.ul.childNodes.length === 0 || awe.ul.hasAttribute('hidden')) {
        minChars = awe.minChars
        // ignore that the input value is empty
        awe.minChars = 0
        // show the suggestion list
        awe.evaluate()
        awe.minChars = minChars
      } else {
        awe.close()
      }
    }
  }

  // Return text with mark tags arround matching input. Don't replace inside <HTML> tags.
  // When startsWith is true, mark only the matching begin text.
  function _mark (text, input, startsWith) {
    var searchText = $.regExpEscape(_htmlEscape(input).trim())
    var regExp = searchText.length <= 0 ? null : startsWith ? RegExp('^' + searchText, 'i') : RegExp('(?!<[^>]+?>)' + searchText + '(?![^<]*?>)', 'gi')
    return text.replace(regExp, '<mark>$&</mark>')
  }

  // Recursive jsonFlatten function
  function _jsonFlatten (result, cur, prop, level, opts) {
    var root = opts.root /* filter resulting json tree on root property (optional) */
    var value = opts.value /* search for this property and copy it's value to a new 'value' property
                                     (optional, do not specify it if the json array contains plain strings) */
    var label = opts.label || opts.value /* search this property and copy it's value to a new 'label' property.
                                     If there is a 'opts.value' field but no 'opts.label', assume label is the same. */
    var isEmpty = true
    var arrayResult = []
    var j
    // at top level, look if there is a property which starts with root (if specified)
    if (level === 0 && root && prop && (prop + '.').lastIndexOf(root + '.', 0) !== 0 && (root + '.').lastIndexOf(prop + '.', 0) !== 0) {
      return result
    }
    // handle current part of the json tree
    if (Object(cur) !== cur) {
      if (prop) {
        result[prop] = cur
      } else {
        result = cur
      }
    } else if (Array.isArray(cur)) {
      for (j = 0; j < cur.length; j++) {
        arrayResult.push(_jsonFlatten({}, cur[j], '', level + 1, opts))
      }
      if (prop) {
        result[prop] = arrayResult
      } else {
        result = arrayResult
      }
    } else {
      for (j in cur) {
        isEmpty = false
        _jsonFlatten(result, cur[j], prop ? prop + '.' + j : j, level, opts)
      }
      if (isEmpty && prop) result[prop] = {}
    }
    // for arrays at top and subtop level
    if (level < 2 && prop) {
      // if a 'value' is specified and found a mathing property, create extra 'value' property.
      if (value && (prop + '.').lastIndexOf(value + '.', 0) === 0) { result.value = result[prop] }
      // if a 'label' is specified and found a mathing property, create extra 'label' property.
      if (label && (prop + '.').lastIndexOf(label + '.', 0) === 0) { result.label = result[prop] }
    }
    if (level === 0) {
      // Make sure that both value and label properties exist, even if they are nil.
      // This is handy with limit 0 or 1 when the result doesn't have to contain an array.
      if (value && !('value' in result)) { result.value = null }
      if (label && !('label' in result)) { result.label = null }
    }
    return result
  }

  // Stop AwesompleteUtil; detach event handlers from the Awesomplete object.
  function _detach () {
    var t = this
    var elem = t.awe.input
    var boundMatch = t.boundMatch
    var boundOnInput = t.boundOnInput
    var boundOnKeydown = t.boundOnKeydown
    var boundSelect = t.boundSelect

    elem.removeEventListener(_AWE_SELECT, boundSelect)
    elem.removeEventListener(_AWE_LOAD, boundMatch)
    elem.removeEventListener(_AWE_CLOSE, boundMatch)
    elem.removeEventListener('blur', boundMatch)
    elem.removeEventListener('input', boundOnInput)
    elem.removeEventListener('keydown', boundOnKeydown)
  }

  //
  // public methods
  //

  return {

    // ajax call for url + val + urlEnd. fn is the callback function. xhr parameter is optional.
    ajax: function (url, urlEnd, val, fn, xhr) {
      xhr = xhr || new XMLHttpRequest()
      xhr.open('GET', url + encodeURIComponent(val) + (urlEnd || ''))
      xhr.onload = fn
      xhr.send()
      return xhr
    },

    // Convert input before comparing it with suggestion. lowercase and trim the text
    convertInput: function (text) {
      return typeof text === 'string' ? text.trim().toLowerCase() : ''
    },

    // item function as defined in Awesomplete.
    // item(html, input). input is optional and ignored in this implementation
    item: _item,

    // Set a new suggestion list. Trigger loadcomplete event.
    // load(awesomplete, list, queryVal)
    load: _loadComplete,

    // Return text with mark tags arround matching input. Don't replace inside <HTML> tags.
    // When startsWith is true, mark only the matching begin text.
    // mark(text, input, startsWith)
    mark: _mark,

    // highlight items: Marks input in the first line, not in the optional description
    itemContains: function (text, input) {
      var arr
      if (input.trim().length > 0) {
        arr = ('' + text).split(/<p>/)
        arr[0] = _mark(arr[0], input)
        text = arr.join('<p>')
      }
      return _item(text, input)
    },

    // highlight items: mark all occurrences of the input text
    itemMarkAll: function (text, input) {
      return _item(input.trim() === '' ? '' + text : _mark('' + text, input), input)
    },

    // highlight items: mark input in the begin text
    itemStartsWith: function (text, input) {
      return _item(input.trim() === '' ? '' + text : _mark('' + text, input, true), input)
    },

    // create Awesomplete object for input control elemId. opts are passed unchanged to Awesomplete.
    create: function (elemId, utilOpts, opts) {
      opts.item = opts.item || this.itemContains /* by default uses itemContains, can be overriden */
      var awe = new Awesomplete(elemId, opts)
      awe.utilprops = utilOpts || {}
      // loadall is true if there is no url (there is a static data-list)
      if (!awe.utilprops.url && typeof awe.utilprops.loadall === 'undefined') {
        awe.utilprops.loadall = true
      }
      awe.utilprops.ajax = awe.utilprops.ajax || this.ajax /* default ajax function can be overriden */
      awe.utilprops.convertInput = awe.utilprops.convertInput || this.convertInput /* the same applies for convertInput */
      return awe
    },

    // attach Awesomplete object to event listeners
    attach: function (awe) {
      var elem = awe.input
      var boundMatch = _match.bind(awe)
      var boundOnKeydown = _onKeydown.bind(awe)
      var boundOnInput = _onInput.bind(awe)
      var boundSelect = _select.bind(awe)
      var boundDetach = _detach.bind({
        awe: awe,
        boundMatch: boundMatch,
        boundOnInput: boundOnInput,
        boundOnKeydown: boundOnKeydown,
        boundSelect: boundSelect
      })
      var events = {
        keydown: boundOnKeydown,
        input: boundOnInput
      }
      events.blur = events[_AWE_CLOSE] = events[_AWE_LOAD] = boundMatch
      events[_AWE_SELECT] = boundSelect
      $.bind(elem, events)

      awe.utilprops.detach = boundDetach
      // Perform ajax call if prepop is true and there is an initial input value, or when all values must be loaded (loadall)
      if (awe.utilprops.prepop && (awe.utilprops.loadall || elem.value.length > 0)) {
        awe.utilprops.val = awe.utilprops.convertInput.call(awe, elem.value)
        _lookup(awe, awe.utilprops.val)
      }
      return awe
    },

    // update input value via javascript. Use prepop=true when this is an initial/prepopulation value.
    update: function (awe, value, prepop) {
      awe.input.value = value
      return _update(awe, value, prepop)
    },

    // create and attach Awesomplete object for input control elemId. opts are passed unchanged to Awesomplete.
    start: function (elemId, utilOpts, opts) {
      return this.attach(this.create(elemId, utilOpts, opts))
    },

    // Stop AwesompleteUtil; detach event handlers from the Awesomplete object.
    detach: function (awe) {
      if (awe.utilprops.detach) {
        awe.utilprops.detach()
        delete awe.utilprops.detach
      }
      return awe
    },

    // Create function to copy a field from the selected autocomplete item to another DOM element.
    // dataField can be null.
    createCopyFun: function (sourceId, dataField, targetId) {
      return _copyFun.bind({ sourceId: sourceId, dataField: dataField, targetId: $(targetId) || targetId })
    },

    // attach copy function to event listeners. prepop is optional and by default true.
    // if true the copy function will also listen to awesomplete-prepop events.
    // The optional listenEl is the element that listens, defaults to document.body.
    attachCopyFun: function (fun, prepop, listenEl) {
      // prepop parameter defaults to true
      prepop = typeof prepop === 'boolean' ? prepop : true
      listenEl = listenEl || document.body
      listenEl.addEventListener(_AWE_MATCH, fun)
      if (prepop) listenEl.addEventListener(_AWE_PREPOP, fun)
      return fun
    },

    // Create and attach copy function.
    startCopy: function (sourceId, dataField, targetId, prepop) {
      var sourceEl = $(sourceId)
      return this.attachCopyFun(this.createCopyFun(sourceEl || sourceId, dataField, targetId), prepop, sourceEl)
    },

    // Stop copy function. Detach it from event listeners.
    // The optional listenEl must be the same element that was used during startCopy/attachCopyFun;
    // in general: Awesomplete.$(sourceId). listenEl defaults to document.body.
    detachCopyFun: function (fun, listenEl) {
      listenEl = listenEl || document.body
      listenEl.removeEventListener(_AWE_PREPOP, fun)
      listenEl.removeEventListener(_AWE_MATCH, fun)
      return fun
    },

    // Create function for combobox button (btnId) to toggle dropdown list.
    createClickFun: function (btnId, awe) {
      return _clickFun.bind({ btnId: btnId, awe: awe })
    },

    // Attach click function for combobox to click event.
    // The optional listenEl is the element that listens, defaults to document.body.
    attachClickFun: function (fun, listenEl) {
      listenEl = listenEl || document.body
      listenEl.addEventListener('click', fun)
      return fun
    },

    // Create and attach click function for combobox button. Toggles open/close of suggestion list.
    startClick: function (btnId, awe) {
      var btnEl = $(btnId)
      return this.attachClickFun(this.createClickFun(btnEl || btnId, awe), btnEl)
    },

    // Stop click function. Detach it from event listeners.
    // The optional listenEl must be the same element that was used during startClick/attachClickFun;
    // in general: Awesomplete.$(btnId). listenEl defaults to document.body.
    detachClickFun: function (fun, listenEl) {
      listenEl = listenEl || document.body
      listenEl.removeEventListener('click', fun)
      return fun
    },

    // filter function as specified in Awesomplete. Filters suggestion list on items containing input value.
    // Awesomplete.FILTER_CONTAINS filters on data.label, however
    // this function filters on value and not on the shown label which may contain markup.
    filterContains: function (data, input) {
      return Awesomplete.FILTER_CONTAINS(data.value, input)
    },

    // filter function as specified in Awesomplete. Filters suggestion list on matching begin text.
    // Awesomplete.FILTER_STARTSWITH filters on data.label, however
    // this function filters on value and not on the shown label which may contain markup.
    filterStartsWith: function (data, input) {
      return Awesomplete.FILTER_STARTSWITH(data.value, input)
    },

    // Flatten JSON.
    // { "a":{"b":{"c":[{"d":{"e":1}}]}}} becomes {"a.b.c":[{"d.e":1}]}.
    // This function can be bind to configure it with extra options;
    //   bind({root: '<root path>', value: '<value property>', label: '<label property>'})
    jsonFlatten: function (data) {
      // start json tree recursion
      return _jsonFlatten({}, data, '', 0, this)
    }
  }
}())
