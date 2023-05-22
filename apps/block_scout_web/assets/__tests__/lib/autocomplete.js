/**
 * @jest-environment jsdom
 */

 import { searchEngine } from '../../js/lib/autocomplete'

 test('searchEngine', () => {
    expect(searchEngine('qwe', {
        'name': 'Test',
        'symbol': 'TST',
        'address_hash': '0x000',
        'tx_hash': '0x000',
        'block_hash': '0x000'
    })).toEqual(undefined)

    expect(searchEngine('tes', {
        'name': 'Test',
        'symbol': 'TST',
        'address_hash': '0x000',
        'tx_hash': '0x000',
        'block_hash': '0x000'
    })).toEqual('<div><div>0x000</div><div><b><mark class=\'autoComplete_highlight\'>Tes</mark>t</b> (TST)</div></div>')

    expect(searchEngine('qwe', {
        'name': 'qwe1\'"><iframe/onload=console.log(123)>${7*7}{{7*7}}{{\'7\'*\'7\'}}',
        'symbol': 'qwe1\'"><iframe/onload=console.log(123)>${7*7}{{7*7}}{{\'7\'*\'7\'}}',
        'address_hash': '0x000',
        'tx_hash': '0x000',
        'block_hash': '0x000'
    })).toEqual('<div><div>0x000</div><div><b><mark class=\'autoComplete_highlight\'>qwe</mark>1&#039;&quot;&gt;&lt;iframe/onload=console.log(123)&gt;${7*7}{{7*7}}{{&#039;7&#039;*&#039;7&#039;}}</b> (<mark class=\'autoComplete_highlight\'>qwe</mark>1&#039;&quot;&gt;&lt;iframe/onload=console.log(123)&gt;${7*7}{{7*7}}{{&#039;7&#039;*&#039;7&#039;}})</div></div>')
 })
