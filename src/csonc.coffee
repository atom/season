path = require 'path'
_ = require 'underscore'
optimist = require 'optimist'
CSON = require './cson'

module.exports = (argv=[]) ->
  options = optimist(argv)
  options.usage('Usage: csonc input_file [output_file]')
  options.alias('r', 'root')
         .boolean('r')
         .describe('r', 'Require that the input file contain an object at the root.')
         .default('r', false)
  argv = options.argv
  [inputFile, outputFile] = argv._

  if inputFile?.length > 0
    inputFile = path.resolve(process.cwd(), inputFile)
  else
    options.showHelp(console.error)
    process.exit(1)
    return

  if outputFile?.length > 0
    outputFile = path.resolve(process.cwd(), outputFile)
  else
    outputName = "#{path.basename(inputFile, path.extname(inputFile))}.json"
    outputFile = path.join(path.dirname(inputFile), outputName)

  try
    object = CSON.readFileSync(inputFile)
    if argv.r and (!_.isObject(object) or _.isArray(object))
      console.error("#{inputFile} does not contain a root object")
      process.exit(1)
      return
  catch e
    console.error("Parsing #{inputFile} failed:", e.message)
    process.exit(1)

  CSON.writeFileSync(outputFile, object)
