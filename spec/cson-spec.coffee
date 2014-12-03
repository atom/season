path = require 'path'
util = require 'util'
fs = require 'fs'
temp = require 'temp'
CSON = require '../lib/cson'

describe "CSON", ->
  beforeEach ->
    CSON.setCacheDir(null)

  describe ".stringify(object)", ->
    describe "when the object is undefined", ->
      it "throws an exception", ->
        expect(-> CSON.stringify()).toThrow()

    describe "when the object is a function", ->
      it "throws an exception", ->
        expect(-> CSON.stringify(-> 'function')).toThrow()

    describe "when the object contains a function", ->
      it "throws an exception", ->
        expect(-> CSON.stringify(a:  -> 'function')).toThrow()

    describe "when formatting an undefined key", ->
      it "does not include the key in the formatted CSON", ->
        expect(CSON.stringify(b: 1, c: undefined)).toBe '{\n  b: 1\n}'

    describe "when formatting a string", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: 'b')).toBe '{\n  a: "b"\n}'

      it "doesn't escape single quotes", ->
        expect(CSON.stringify(a: "'b'")).toBe '''{
          a: "'b'"
        }'''

      it "escapes double quotes", ->
        expect(CSON.stringify(a: '"b"')).toBe '''{
          a: "\\"b\\""
        }'''

      it "turns strings with newlines into triple-apostrophe strings", ->
        expect(CSON.stringify("a\nb")).toBe """'''
          a
          b
        '''"""

      it "escapes triple-apostrophes in triple-apostrophe strings", ->
        expect(CSON.stringify("a\n'''")).toBe """'''
          a
          \\\'''
        '''"""

    describe "when formatting a boolean", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(true)).toBe 'true'
        expect(CSON.stringify(false)).toBe 'false'
        expect(CSON.stringify(a: true)).toBe '{\n  a: true\n}'
        expect(CSON.stringify(a: false)).toBe '{\n  a: false\n}'

    describe "when formatting a number", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(54321.012345)).toBe '54321.012345'
        expect(CSON.stringify(a: 14)).toBe '{\n  a: 14\n}'
        expect(CSON.stringify(a: 1.23)).toBe '{\n  a: 1.23\n}'

    describe "when formatting null", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(null)).toBe 'null'
        expect(CSON.stringify(a: null)).toBe '{\n  a: null\n}'

    describe "when formatting an array", ->
      describe "when the array is empty", ->
        it "puts the array on a single line", ->
          expect(CSON.stringify([])).toBe "[]"

      it "returns formatted CSON", ->
        expect(CSON.stringify(a: ['b'])).toBe '''{
          a: [
            "b"
          ]
        }'''
        expect(CSON.stringify(a: ['b', 4])).toBe '''{
          a: [
            "b"
            4
          ]
        }'''

      describe "when the array has an undefined value", ->
        it "formats the undefined value as null", ->
          expect(CSON.stringify(['a', undefined, 'b'])).toBe '''[
            "a"
            null
            "b"
          ]'''

      describe "when the array contains an object", ->
        it "wraps the object in {}", ->
          expect(CSON.stringify([{a:'b', a1: 'b1'}, {c: 'd'}])).toBe '''[
            {
              a: "b"
              a1: "b1"
            }
            {
              c: "d"
            }
          ]'''

    describe "when formatting an object", ->
      describe "when the object is empty", ->
        it "returns {}", ->
          expect(CSON.stringify({})).toBe "{}"

      it "returns formatted CSON", ->
        expect(CSON.stringify(a: {b: 'c'})).toBe '''{
          a: {
            b: "c"
          }
        }'''
        expect(CSON.stringify(a:{})).toBe '''{
          a: {}
        }'''
        expect(CSON.stringify(a:[])).toBe '''{
          a: []
        }'''

      it "escapes object keys", ->
        expect(CSON.stringify('\\t': 3)).toBe '''{
          "\\\\t": 3
        }'''

  describe "when converting back to an object", ->
    it "produces the original object", ->
      object =
        a: true
        b: 20
        c:
          d: ['a', 'b']
        e:
          f: true

      cson = CSON.stringify(object)
      CSONParser = require 'cson-safe'
      evaledObject = CSONParser.parse(cson)
      expect(evaledObject).toEqual object

  describe ".isObjectPath(objectPath)", ->
    it "returns true if the path has an object extension", ->
      expect(CSON.isObjectPath('/test2.json')).toBe true
      expect(CSON.isObjectPath('/a/b.cson')).toBe true
      expect(CSON.isObjectPath()).toBe false
      expect(CSON.isObjectPath(null)).toBe false
      expect(CSON.isObjectPath('')).toBe false
      expect(CSON.isObjectPath('a/b/c.txt')).toBe false

  describe ".resolve(objectPath)", ->
    it "returns the path to the object file", ->
      objectDir = temp.mkdirSync('season-object-dir-')
      file1 = path.join(objectDir, 'file1.json')
      file2 = path.join(objectDir, 'file2.cson')
      file3 = path.join(objectDir, 'file3.json')
      folder1 = path.join(objectDir, 'folder1.json')
      fs.mkdirSync(folder1)
      fs.writeFileSync(file1, '{}')
      fs.writeFileSync(file2, '{}')
      fs.writeFileSync(file3, '{}')

      expect(CSON.resolve(file1)).toBe file1
      expect(CSON.resolve(file2)).toBe file2
      expect(CSON.resolve(file3)).toBe file3
      expect(CSON.resolve(path.join(objectDir, 'file4'))).toBe null
      expect(CSON.resolve(folder1)).toBe null
      expect(CSON.resolve()).toBe null
      expect(CSON.resolve(null)).toBe null
      expect(CSON.resolve('')).toBe null

  describe ".writeFile(objectPath, object, callback)", ->
    object =
      a: 1
      b: 2

    describe "when called with a .json path", ->
      it "writes the object and calls back", ->
        jsonPath = path.join(temp.mkdirSync('season-object-dir-'), 'file1.json')
        callback = jasmine.createSpy('callback')
        CSON.writeFile(jsonPath, object, callback)

        waitsFor ->
          callback.callCount is 1

        runs ->
          expect(CSON.readFileSync(jsonPath)).toEqual object

    describe "when called with a .cson path", ->
      csonPath = path.join(temp.mkdirSync('season-object-dir-'), 'file1.cson')

      describe "when called with an invalid object", ->
        it "calls back with an error", ->
          callback = jasmine.createSpy('callback')
          CSON.writeFile(csonPath, undefined, callback)

          waitsFor ->
            callback.callCount is 1

          runs ->
            expect(util.isError(callback.mostRecentCall.args[0])).toBeTruthy()

      it "writes the object and calls back", ->
        callback = jasmine.createSpy('callback')
        CSON.writeFile(csonPath, object, callback)

        waitsFor ->
          callback.callCount is 1

        runs ->
          expect(CSON.readFileSync(csonPath)).toEqual object

  describe "caching", ->
    describe "synchronous reads", ->
      it "caches the contents of the compiled CSON files", ->
        samplePath = path.join(__dirname, 'fixtures', 'sample.cson')
        cacheDir = temp.mkdirSync('cache-dir')
        CSON.setCacheDir(cacheDir)
        CSONParser = require 'cson-safe'
        spyOn(CSONParser, 'parse').andCallThrough()

        expect(CSON.readFileSync(samplePath)).toEqual {a: 1, b: c: true}
        expect(CSONParser.parse.callCount).toBe 1
        CSONParser.parse.reset()
        expect(CSON.readFileSync(samplePath)).toEqual {a: 1, b: c: true}
        expect(CSONParser.parse.callCount).toBe 0

    describe "asynchronous reads", ->
      it "caches the contents of the compiled CSON files", ->
        samplePath = path.join(__dirname, 'fixtures', 'sample.cson')
        cacheDir = temp.mkdirSync('cache-dir')
        CSON.setCacheDir(cacheDir)
        CSONParser = require 'cson-safe'
        spyOn(CSONParser, 'parse').andCallThrough()

        sample = null
        CSON.readFile samplePath, (error, object) -> sample = object
        waitsFor -> sample?
        runs ->
          expect(sample).toEqual {a: 1, b: c: true}
          expect(CSONParser.parse.callCount).toBe 1
          CSONParser.parse.reset()
          sample = null
          CSON.readFile samplePath, (error, object) -> sample = object
        waitsFor -> sample?
        runs ->
          expect(CSONParser.parse.callCount).toBe 0
