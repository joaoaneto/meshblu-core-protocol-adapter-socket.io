_ = require 'lodash'
JobManager = require 'meshblu-core-job-manager'
meshblu = require 'meshblu'

class SocketIOHandler
  constructor: (options) ->
    {@socket,client,timeoutSeconds, @meshbluConfig} = options
    @jobManager = new JobManager client: client, timeoutSeconds: timeoutSeconds

  initialize: =>
    @socket.on 'identity', @onIdentity
    @socket.on 'disconnect', @onDisconnect
    @socket.emit 'identify'

  onDisconnect: =>
    @upstream?.close()

  onIdentity: (auth) =>
    request =
      metadata:
        jobType: 'Authenticate'
        auth: _.pick(auth, 'uuid', 'token')

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @_emitNotReady 504, _.pick(auth, 'uuid', 'token') if error?
      return @_emitNotReady 401, _.pick(auth, 'uuid', 'token') unless response.metadata.code == 204

      @upstream = _.bindAll meshblu.createConnection
        server: @meshbluConfig.server
        port: @meshbluConfig.port
        uuid: auth.uuid
        token: auth.token

      @upstream.on 'ready', @onUpstreamReady
      @upstream.on 'notReady', (response) => @socket.emit 'notReady', response

  onUpstreamReady: (response)=>
    @socket.emit 'ready', response
    @socket.on 'data', @upstream.data
    @socket.on 'device', @upstream.device
    @socket.on 'devices', @upstream.devices
    @socket.on 'generateAndStoreToken', @upstream.generateAndStoreToken
    @socket.on 'getdata', @upstream.getdata
    @socket.on 'message', @upstream.message
    @socket.on 'register', @upstream.register
    @socket.on 'revokeToken', @upstream.revokeToken
    @socket.on 'subscribe', @upstream.subscribe
    @socket.on 'unregister', @upstream.unregister
    @socket.on 'unsubscribe', @upstream.unsubscribe
    @socket.on 'update', @upstream.update
    @socket.on 'whoami', @upstream.whoami

  _emitNotReady: (code, auth) =>
    @socket.emit 'notReady',
      uuid:  auth.uuid
      token: auth.token
      api: 'connect'
      status: code

module.exports = SocketIOHandler
