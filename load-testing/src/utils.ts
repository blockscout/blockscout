const fs = require('fs')
const parse = require('csv-parse/lib/sync')

export function loadInputData(filePath: string): Array<string> {

    const fileContents = fs.readFileSync(filePath,'utf8')

    const contents = parse(fileContents, {delimiter: ',', columns: false, skip_empty_lines: true})
    let output = []
    contents.map( (record) => {
        output.push({param0: record[0]})
    })
    return output
}