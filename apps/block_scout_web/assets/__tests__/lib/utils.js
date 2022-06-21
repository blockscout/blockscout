/**
 * @jest-environment jsdom
 */

 import { escapeHtml } from '../../js/lib/utils'

 test('escapeHtml', () => {
    expect(escapeHtml('<script>')).toEqual('&lt;script&gt;')
    expect(escapeHtml('1&')).toEqual('1&amp;')
    expect(escapeHtml('1"')).toEqual('1&quot;')
    expect(escapeHtml('1\'')).toEqual('1&#039;')
 })
