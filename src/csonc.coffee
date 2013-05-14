path = require 'path'
_ = require 'underscore'
CSON = require './cson'

module.exports = (argv=[]) ->
  [inputFile, outputFile] = argv

  if inputFile?.length > 0
    inputFile = path.resolve(process.cwd(), inputFile)
  else
    console.error("Input file must be first argument")
    process.exit(1)
    return

  if outputFile?.length > 0
    outputFile = path.resolve(process.cwd(), outputFile)
  else
    outputName = "#{path.basename(inputFile, path.extname(inputFile))}.json"
    outputFile = path.join(path.dirname(inputFile), outputName)

  object = CSON.readFileSync(inputFile)
  if _.isObject(object)
    CSON.writeFileSync(outputFile, object)
  else
    console.error("Input file does not contain an object: #{inputFile}")
    process.exit(1)
