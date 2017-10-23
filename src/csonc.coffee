fs = require 'fs'
path = require 'path'
yargs = require 'yargs'
CSON = require 'cson-parser'

module.exports = (argv=[]) ->

  options = yargs(argv)
  options.usage """
    Usage: csonc [options] cson_file --output json_file
           csonc [options] < cson_file [> json_file]

    Compiles CSON to JSON.

    If no input file is specified then the CSON is read from standard in.

    If no output file is specified then the JSON is written to standard out.
  """
  options.alias('h', 'help').describe('help', 'Print this help message')
  options.alias('r', 'root').boolean('root').describe('root', 'Require that the input file contain an object at the root').default('root', false)
  options.alias('o', 'output').string('output').describe('output', 'File path to write the JSON output to')
  options.alias('v', 'version').describe('version', 'Print the version')

  {argv} = options
  [inputFile] = argv._
  inputFile = path.resolve(inputFile) if inputFile

  if argv.version
    {version} = require '../package.json'
    console.log(version)
    return

  if argv.help
    options.showHelp()
    return

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
