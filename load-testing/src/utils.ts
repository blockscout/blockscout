
export function loadInputData(filePath: string): Array<string> {

    const fileContents = fs.readFileSync(filePath,'utf8')

    const contents = parse(fileContents, {delimiter: ',', columns: false, skip_empty_lines: true})
    let output = []
    csvAddresses.map( (record) => {
        output.push({hash: record[0]})
    })
    return output
}