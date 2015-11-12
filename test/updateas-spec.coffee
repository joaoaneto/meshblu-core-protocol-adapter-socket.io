Connect = require './connect'

describe 'updateas', ->
  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@jobManager} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  describe 'when called', ->
    beforeEach ->
      request =
        metadata:
          fromUuid: @device.uuid
          toUuid: @device.uuid
        data:
          shock: 'you will not believe it'

      @connection.socket.emit 'updateas', request, @onResponse = sinon.spy()

    it 'should create an UpdateDevice request', (done) ->
      @jobManager.getRequest ['request'], (error, request) =>
        return done error if error?
        expect(request).to.containSubset
          metadata:
            auth:
              uuid: @device.uuid
              token: @device.token
            jobType: 'UpdateDevice'
            toUuid: @device.uuid
          rawData: '{"shock":"you will not believe it"}'
        done()
