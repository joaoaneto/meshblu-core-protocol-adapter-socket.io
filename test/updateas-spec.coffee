Connect = require './connect'

describe 'updateas', ->
  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things)=>
      return done error if error?
      {@sut,@connection} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  describe 'when called', ->
    beforeEach (done) ->
      @connection.socket.emit 'updateas', (@response) => done

    it 'should respond', ->
      expect(@response).to.exist
