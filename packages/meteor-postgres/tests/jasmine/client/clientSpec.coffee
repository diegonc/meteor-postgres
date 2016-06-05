describe 'SQL.Server', ->

  tableTestTasks =
    text: ['$string', '$notnull']

  tableTestUsers =
    username: ['$string', '$notnull']
    age: ['$number']

  sqlStub = (name) ->
    stub = SQL.Client()
    stub.table = name
    stub

  testTasks = sqlStub 'test_tasks'
  testUsers = sqlStub 'test_users'
  testQuotes = sqlStub 'test_quotes'

  beforeEach (done) ->
    try
      testTasks.dropTable().save()
      testUsers.dropTable().save()
    catch e
      console.error e

    testTasks.createTable(tableTestTasks)
    _(3).times (n) -> testTasks.insert({ id: "#{n+1}", text: "testing#{n + 1}" }).save()
    _(5).times (n) -> testTasks.insert({ id: "#{n+1+3}", text: "testing1" }).save()


    testUsers.createTable(tableTestUsers)
    _(3).times (n) ->
      testUsers.insert({ id: "#{n*2+1}", username: "eddie#{n + 1}", age: 2 * n }).save()
    _(3).times (n) ->
      testUsers.insert({ id: "#{n*2+2}", username: "paulo", age: 27 }).save()
    done()

  describe 'createTable', ->

    it 'has string IDs', ->
      console.log testTasks.select().fetch()
      result = testTasks.findOne().fetch()
      expect(result[0].id).toEqual(jasmine.any(String))

  describe 'fetch', ->

    describe 'findOne', ->

      it 'returns first object without argument', ->
        result = testTasks.findOne().fetch()
        expect(result).toEqual(jasmine.any(Array))
        expect(result?.length).toBe(1)
        expect(result[0]).toEqual(jasmine.any(Object))
        expect(result[0].text).toEqual('testing1')

      it 'returns object with id as argument', ->
        result = testTasks.findOne('3').fetch()
        expect(result).toEqual(jasmine.any(Array))
        expect(result?.length).toBe(1)
        expect(result[0]).toEqual(jasmine.any(Object))
        expect(result[0].text).toEqual('testing3')

    describe 'where', ->

      it 'works with basic where', ->
        string_where = testTasks.select().where('text = ?', 'testing1').fetch()
        expect(string_where?.length).toBe(6)
        _.each string_where, (row) -> expect(row?.text).toBe('testing1')

        array_where = testTasks.select().where('text = ?', ['testing1']).fetch()
        expect(JSON.stringify(array_where)).toEqual(JSON.stringify(string_where))

      it 'works with basic where and limit', ->
        result = testTasks.select().where('text = ?', 'testing1').limit(3).fetch()
        expect(result.length).toBe(3)
        _.each result, (row) -> expect(row?.text).toBe('testing1')

      it 'works with array where', ->
        result = testTasks.select().where('text = ?', ['testing1', 'testing2']).fetch()
        expect(result.length).toBe(7)
        expect(result[1].text).toBe('testing2')

      it 'works with multiple placeholder', ->
        result = testTasks.select().where('id = ? AND text = ?', '2', 'testing2').fetch()
        expect(result.length).toBe(1)

      it 'works with multiple placeholders and array wheres', ->
        result = testTasks.select().where('id = ? AND text = ?', ['1', '2', '3'], ['testing1', 'testing2']).fetch()
        expect(result.length).toBe(2)
        expect(result[0].id).toBe('1')
        expect(result[1].id).toBe('2')
        expect(result[0].text).toBe('testing1')
        expect(result[1].text).toBe('testing2')

    describe 'order', ->

      it 'orders correct and ASC by default', ->
        asc_default = testTasks.select().order('text').fetch()
        asc = testTasks.select().order('text ASC').fetch()
        desc = testTasks.select().order('text DESC').fetch()
        expect(JSON.stringify(asc_default)).toEqual(JSON.stringify(asc))
        expect(JSON.stringify(asc_default)).not.toEqual(JSON.stringify(desc))
        expect(JSON.stringify(asc[6])).toEqual(JSON.stringify(desc[1]))

    describe 'first', ->

      it 'picks the right `first`', ->
        first = testTasks.select().where('text = ?', 'testing1').order('id DESC').limit(3).first().fetch()
        second = testTasks.select().first(2).fetch()
        expect(JSON.stringify(first[0])).toEqual(JSON.stringify(second[0]))

    describe 'last', ->

      it 'picks the right `last`', ->
        first = testTasks.select().last(4).fetch()
        expect(first[1].id).toEqual('7')
        second = testTasks.select().where('text = ?', 'testing1').order('id DESC').limit(3).last().fetch()
        expect(JSON.stringify(first[0])).toEqual(JSON.stringify(second[0]))

    describe 'take', ->

      it 'picks the right with `take`', ->
        first = testTasks.select().order('id DESC').limit(3).take().fetch()
        second = testTasks.select().take().fetch()
        expect(JSON.stringify(first)).toEqual(JSON.stringify(second))

  describe 'save', ->

    describe 'insert', ->

      it 'creates a string ID if none provided on INSERT', ->
        testTasks.insert({ text: 'stringIdTest' }).save()
        result = testTasks.select().where('text = ?', 'stringIdTest').fetch()
        expect(result[0].id).toEqual(jasmine.any(String))
        expect(result[0].id.split('').length).toBeGreaterThan(7)

    describe 'update', ->

      it 'updates correctly with single argument', ->
        before = testTasks.select().where('text = ?', 'testing1').fetch()
        testTasks.update({ text: 'testing1' }).where('id = ?', '2').save()
        after = testTasks.select().where('text = ?', 'testing1').fetch()
        expect(before.length + 1).toEqual(after.length)

      it 'calls the server save method', ->
        spyOn(Meteor, 'call')
        testTasks.update({ text: 'testing1' }).where('id = ?', '2').save()
        expect(Meteor.call).toHaveBeenCalled()
        expect(Meteor.call.calls.argsFor(0)[0]).toBe('test_tasks_save')


      it 'updates correctly with multiple arguments', ->
        testUsers.update({username: 'PaulOS', age: 100}).where('username = ?', 'paulo').save()
        result = testUsers.select().where('username = ?', 'PaulOS').fetch()
        expect(result.length).toBe(3)
        _.each result, (item) ->
          expect(item?.username).toEqual('PaulOS')
          expect(item?.age).toBe(100)

      it 'updates not when where does not find entries', ->
        testUsers.update({username: 'PaulOS', age: 100}).where('username = ?', 'notexist').save()
        result = testUsers.select().where('username = ?', 'PaulOS').fetch()
        expect(result.length).toBe(3)

      it 'updates all', ->
        first = testTasks.select().where('text = ?', 'testing1').fetch()
        testTasks.update( {text: 'testing3'} ).save()
        second = testTasks.select().where('text = ?', 'testing3').fetch()
        expect(first.length).toBe(7)
        expect(second.length).toBe(9)

    describe 'remove', ->

      it 'removes correctly', ->
        testTasks.where('id = ?', '2').remove().save()
        result = testTasks.select().fetch()
        expect(result.length).toBe(8)

      it 'removes all', ->
        testTasks.remove().save()
        result = testTasks.select().fetch()
        expect(result.length).toBe(0)

    describe 'quoting', ->
      fieldsContainingSpecialChars =
        'position.lat': ['$float']
        'position.lng': ['$float']

      setup = ->
        testQuotes.createTable(fieldsContainingSpecialChars)

      populate = (objs...) ->
        _.map(objs, (o) ->
          testQuotes.insert(o).save())

      tearDown = ->
        testQuotes.dropTable().save()

      it 'createTable should allow fields with special characters', ->
        expect(-> setup()).not.toThrow()
        tearDown()

      it 'insert should allow fields with special characters', ->
        setup()
        try
          populate({'position.lat': 34.5, 'position.lng': 56.8})
          result = testQuotes.select().fetch()
          expect(result).toEqual(jasmine.any(Array))
          expect(result[0]).toEqual(jasmine.any(Object))
          expect(result[0]['position.lat']).toBe(34.5)
        finally
          tearDown()

      it 'update should allow fields with special characters', ->
        setup()
        try
          populate({id: 'xy', 'position.lat': 34.5, 'position.lng': 56.8})
          testQuotes.update({'position.lat': 12.4}).where('id = ?', 'xy').save()
          result = testQuotes.select().where('id = ?', 'xy').fetch()
          expect(result).toEqual(jasmine.any(Array))
          expect(result[0]).toEqual(jasmine.any(Object))
          expect(result[0]['position.lat']).toBe(12.4)
        finally
          tearDown()

      it 'select should allow fields with special characters', ->
        setup()
        try
          populate({id: 'yz', 'position.lat': 34.5, 'position.lng': 56.8})
          result = testQuotes.select('position.lat').where('id = ?', 'yz').fetch()
          expect(result).not.toEqual(jasmine.any(Error))
          expect(result).toEqual(jasmine.any(Array))
          expect(result.length).toBe(1)
          expect(result[0]['position.lat']).toBe(34.5)
        finally
          tearDown()

      it 'where clauses must be explicitly quoted with backticks', ->
        setup()
        try
          populate({id: 'wz', 'position.lat': 34.5, 'position.lng': 56.8})
          result = testQuotes.select().where('`position.lat` = ? and id = ?', 34.5, 'wz').fetch()
          expect(result).not.toEqual(jasmine.any(Error))
          expect(result).toEqual(jasmine.any(Array))
          expect(result.length).toBe(1)
          expect(result[0]['position.lat']).toBe(34.5)
        finally
          tearDown()
