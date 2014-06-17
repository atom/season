path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
csonc = require '../lib/csonc'

describe "CSON compilation to JSON", ->
  [compileDir, inputFile, outputFile] = []

  beforeEach ->
    compileDir = temp.mkdirSync('season-compile-dir-')
    inputFile = path.join(compileDir, 'input.cson')
    outputFile = path.join(compileDir, 'input.json')
    spyOn(process, 'exit')
    spyOn(console, 'error')

  it "writes the output file to the input file's directory with the same base name and .json extension", ->
    fs.writeFileSync(inputFile, 'deadmau: 5')
    csonc([inputFile, '--output', outputFile])
    expect(fs.readFileSync(outputFile, {encoding: 'utf8'})).toBe '{\n  "deadmau": 5\n}\n'

  describe "when a valid CSON file is specified", ->
    it "converts the file to JSON and writes it out", ->
      fs.writeFileSync(inputFile, 'a: 3')
      csonc([inputFile, '--output', outputFile])
      expect(fs.readFileSync(outputFile, {encoding: 'utf8'})).toBe '{\n  "a": 3\n}\n'

  describe "when an input CSON file is invalid CoffeeScript", ->
    it "logs an error and exits", ->
      fs.writeFileSync(inputFile, '<->')
      csonc([inputFile, '--output', outputFile])
      expect(process.exit.mostRecentCall.args[0]).toBe 1
      expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0

  describe "when the input CSON file does not exist", ->
    it "logs an error and exits", ->
      csonc([inputFile])
      expect(process.exit.mostRecentCall.args[0]).toBe 1
      expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0

  describe "when the root option is set", ->
    describe "when the input CSON file contains a root object", ->
      it "converts the file to JSON and writes it out", ->
        fs.writeFileSync(inputFile, 'a: 3')
        csonc(['--root', inputFile, '--output', outputFile])
        expect(fs.readFileSync(outputFile, {encoding: 'utf8'})).toBe '{\n  "a": 3\n}\n'

    describe "when the input CSON file contains a root array", ->
      it "logs and error and exits", ->
        fs.writeFileSync(inputFile, '[1,2,3]')
        csonc(['--root', inputFile, '--output', outputFile])
        expect(process.exit.mostRecentCall.args[0]).toBe 1
        expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
