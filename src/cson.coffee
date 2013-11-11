crypto = require 'crypto'
path = require 'path'

_ = require 'underscore'
fs = require 'fs-plus'
CoffeeScript = null

multiplyString = (string, n) -> new Array(1 + n).join(string)

stringifyIndent = (level=0) -> multiplyString(' ', Math.max(level, 0))

stringifyString = (string) ->
  string = JSON.stringify(string)
  string = string[1...-1]               # Remove surrounding double quotes
  string = string.replace(/\\"/g, '"')  # Unescape escaped double quotes
  string = string.replace(/'/g, '\\\'') # Escape single quotes
  "'#{string}'"                         # Wrap in single quotes

stringifyBoolean = (boolean) -> "#{boolean}"

stringifyNumber =  (number) -> "#{number}"

stringifyNull = -> 'null'

stringifyArray = (array, indentLevel=0) ->
  return '[]' if array.length is 0

  cson = '[\n'
  for value in array
    indent = stringifyIndent(indentLevel + 2)
    cson += indent
    if _.isString(value)
      cson += stringifyString(value)
    else if _.isBoolean(value)
      cson += stringifyBoolean(value)
    else if _.isNumber(value)
      cson += stringifyNumber(value)
    else if _.isNull(value) or value is undefined
      cson += stringifyNull(value)
    else if _.isArray(value)
      cson += stringifyArray(value, indentLevel + 2)
    else if _.isObject(value)
      cson += "{\n#{stringifyObject(value, indentLevel + 4)}\n#{indent}}"
    else
      throw new Error("Unrecognized type for array value: #{value}")
    cson += '\n'
  "#{cson}#{stringifyIndent(indentLevel)}]"

stringifyObject = (object, indentLevel=0) ->
  return '{}' if _.isEmpty(object)

  cson = ''
  prefix = ''
  for key, value of object
    continue if value is undefined
    if _.isFunction(value)
      throw new Error("Function specified as value to key: #{key}")

    cson += "#{prefix}#{stringifyIndent(indentLevel)}'#{key}':"
    if _.isString(value)
      cson += " #{stringifyString(value)}"
    else if _.isBoolean(value)
      cson += " #{stringifyBoolean(value)}"
    else if _.isNumber(value)
      cson += " #{stringifyNumber(value)}"
    else if _.isNull(value)
      cson += " #{stringifyNull(value)}"
    else if _.isArray(value)
      cson += " #{stringifyArray(value, indentLevel)}"
    else if _.isObject(value)
      if _.isEmpty(value)
        cson += ' {}'
      else
        cson += "\n#{stringifyObject(value, indentLevel + 2)}"
    else
      throw new Error("Unrecognized value type for key: #{key} with value: #{value}")
    prefix = '\n'
  cson

csonCache = null

getCachePath = (cson) ->
  digest = crypto.createHash('sha1').update(cson, 'utf8').digest('hex')
  path.join(csonCache, "#{digest}.json")

writeCacheFileSync = (cachePath, object) ->
  try
    fs.writeFileSync(cachePath, JSON.stringify(object))

writeCacheFile = (cachePath, object) ->
  fs.writeFile(cachePath, JSON.stringify(object))

parseObject = (objectPath, contents) ->
  if path.extname(objectPath) is '.cson'
    CoffeeScript ?= require 'coffee-script'
    CoffeeScript.eval(contents, {bare: true, sandbox: true})
  else
    JSON.parse(contents)

parseContentsSync = (objectPath, cachePath, contents) ->
  object = parseObject(objectPath, contents)
  writeCacheFileSync(cachePath, object) if cachePath
  object

parseContents = (objectPath, cachePath, contents, callback) ->
  try
    object = parseObject(objectPath, contents)
    writeCacheFile(cachePath, object) if cachePath
    callback?(null, object)
  catch parseError
    callback?(parseError)

if fs.statSyncNoException?
  exists = (objectPath) ->
    if stats = fs.statSyncNoException(objectPath)
      stats.isFile()
    else
      false
else
  exists = (objectPath) ->
    try
      fs.statSync(objectPath).isFile()
    catch error
      false

module.exports =
  setCacheDir: (cacheDirectory) -> csonCache = cacheDirectory

  isObjectPath: (objectPath) ->
    return false unless objectPath

    extension = path.extname(objectPath)
    extension is '.cson' or extension is '.json'

  resolve: (objectPath='') ->
    return null unless objectPath

    return objectPath if @isObjectPath(objectPath) and exists(objectPath)

    csonPath = "#{objectPath}.json"
    return csonPath if exists(csonPath)

    jsonPath = "#{objectPath}.cson"
    return jsonPath if exists(jsonPath)

    null

  readFileSync: (objectPath) ->
    contents = fs.readFileSync(objectPath, 'utf8')
    if csonCache and path.extname(objectPath) is '.cson'
      cachePath = getCachePath(contents)
      if exists(cachePath)
        try
          return JSON.parse(fs.readFileSync(cachePath, 'utf8'))

    parseContentsSync(objectPath, cachePath, contents)

  readFile: (objectPath, callback) ->
    fs.readFile objectPath, 'utf8', (error, contents) =>
      if error?
        callback?(error)
      else
        if csonCache and path.extname(objectPath) is '.cson'
          cachePath = getCachePath(contents)
          fs.stat cachePath, (error, stat) ->
            if stat?.isFile()
              fs.readFile cachePath, 'utf8', (error, cached) ->
                try
                  parsed = JSON.parse(cached)
                catch error
                  try
                    parseContents(objectPath, cachePath, contents, callback)
                  return
                callback?(null, parsed)
            else
              parseContents(objectPath, cachePath, contents, callback)
        else
          parseContents(objectPath, null, contents, callback)

  writeFile: (objectPath, object, callback) ->
    try
      contents = @stringifyPath(objectPath, object)
    catch error
      callback(error)
      return

    fs.writeFile(objectPath, "#{contents}\n", callback)

  writeFileSync: (objectPath, object) ->
    fs.writeFileSync(objectPath, "#{@stringifyPath(objectPath, object)}\n")

  stringifyPath: (objectPath, object) ->
    if path.extname(objectPath) is '.cson'
      @stringify(object)
    else
      JSON.stringify(object, undefined, 2)

  stringify: (object) ->
    throw new Error("Cannot stringify undefined object") if object is undefined
    throw new Error("Cannot stringify function: #{object}") if _.isFunction(object)

    return stringifyString(object) if _.isString(object)
    return stringifyBoolean(object) if _.isBoolean(object)
    return stringifyNumber(object) if _.isNumber(object)
    return stringifyNull(object) if _.isNull(object)
    return stringifyArray(object) if _.isArray(object)
    return stringifyObject(object) if _.isObject(object)

    throw new Error("Unrecognized type to stringify: #{object}")
