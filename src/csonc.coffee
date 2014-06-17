fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
CSON = require 'cson-safe'

module.exports = (argv=[]) ->
  options = optimist(argv)
  options.usage """
    Usage: csonc [options] file
           csonc [options] < input_file [> output_file]

    If no input file is specified then the CSON is read from standard in.

    If no output file is specified then the JSON is written to standard out.
  """
  options.alias('r', 'root').boolean('root').describe('root', 'Require that the input file contain an object at the root.').default('root', false)
  options.alias('o', 'output').string('output').describe('output', 'File path to write the JSON output to.')

  {argv} = options
  [inputFile] = argv._
  inputFile = path.resolve(inputFile) if inputFile

  parseData = (data) ->
    try
      object = CSON.parse(data)

      if argv.r and (!_.isObject(object) or _.isArray(object))
        console.error("CSON data does not contain a root object")
        process.exit(1)
        return
    catch error
      console.error("Parsing data failed: #{error.message}")
      process.exit(1)

    json = JSON.stringify(object, undefined, 2) + "\n"
    if argv.output
      outputFile = path.resolve(argv.output)
      try
        fs.writeFileSync(outputFile, json)
      catch error
        console.error("Writing #{outputFile} failed: #{error.code ? error}")
    else
      process.stdout.write(json)

  if inputFile
    try
      parseData(fs.readFileSync(inputFile, 'utf8'))
    catch error
      console.error("Reading #{inputFile} failed: #{error.code ? error}")
      process.exit(1)
  else
    process.stdin.resume()
    process.stdin.setEncoding('utf8')
    data = ''
    process.stdin.on 'data', (chunk) -> data += chunk.toString()
    process.stdin.on 'end', -> parseData(data)
