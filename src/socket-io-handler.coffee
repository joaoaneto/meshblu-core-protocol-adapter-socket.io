_ = require 'lodash'
http = require 'http'
JobManager = require 'meshblu-core-job-manager'
meshblu = require 'meshblu'

class SocketIOHandler
  constructor: (options) ->
    {@socket,@pool,@timeoutSeconds,@meshbluConfig} = options

  initialize: =>
    @socket.on 'identity', @onIdentity
    @socket.on 'disconnect', @onDisconnect
    @socket.emit 'identify'

  doJob: (request, callback) =>
    @pool.acquire (error, client) =>
      return callback error if error?
      jobManager = new JobManager client: client, timeoutSeconds: @timeoutSeconds
      jobManager.do 'request', 'response', request, (error, response) =>
        @pool.release client
        callback error, response

  onDisconnect: =>
    @upstream?.close()

  onIdentity: (auth) =>
    @auth = _.pick auth, 'uuid', 'token'
    @doAuthenticate @auth, (error, response) =>
      return @_emitNotReady 504, @auth if error?
      return @_emitNotReady 401, @auth unless response.metadata.code == 204

      @upstream = _.bindAll meshblu.createConnection
        auto_set_online: @meshbluConfig.auto_set_online
        bufferRate: 0
        skip_resubscribe_on_reconnect: true
        server: @meshbluConfig.server
        port: @meshbluConfig.port
        uuid: @auth.uuid
        token: @auth.token

      @upstream.once 'ready', @setupUpstream
      @upstream.on 'ready', @onUpstreamReady
      @upstream.on 'notReady', (response) =>
        @socket.emit 'notReady', response
      @upstream.on 'config', @onUpstreamConfig
      @upstream.socket.on 'data', @onUpstreamData # data is not proxied by meshblu-npm
      @upstream.on 'message', @onUpstreamMessage

  onUpdateAs: (request, callback) =>
    updateDeviceRequest =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: request.metadata.toUuid
        fromUuid: request.metadata.fromUuid
        auth: @auth
      data: request.data

    @doJob updateDeviceRequest, (error, response) =>
      return callback metadata: {code: 504, status: http.STATUS_CODES[504]} if error?
      callback response

  onWhoami: (request, callback) =>
    whoamiRequest =
      metadata:
        jobType: 'GetDevice'
        toUuid: @auth.uuid
        fromUuid: @auth.uuid
        auth: @auth

    @doJob whoamiRequest, (error, response) =>
      return callback null if error?
      return callback null unless response?
      callback JSON.parse(response.rawData) if response.rawData?

  onUpstreamConfig: (message) =>
    @socket.emit 'config', message

  onUpstreamData: (message) =>
    @socket.emit 'data', message

  onUpstreamMessage: (message) =>
    @socket.emit 'message', message

  onUpstreamReady: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    @socket.emit 'ready', response

  setupUpstream: (response) =>
    @auth.uuid  = response.uuid
    @auth.token = response.token

    @socket.on 'updateas', @onUpdateAs
    @socket.on 'whoami', @onWhoami

    @socket.on 'authenticate', @upstream.authenticate
    @socket.on 'claimdevice', @upstream.claimdevice
    @socket.on 'data', @upstream.data
    @socket.on 'device', @upstream.device
    @socket.on 'devices', @upstream.devices
    @socket.on 'events', @upstream.events
    @socket.on 'generateAndStoreToken', @upstream.generateAndStoreToken
    @socket.on 'getdata', @upstream.getdata
    @socket.on 'getPublicKey', @upstream.getPublicKey
    @socket.on 'localdevices', @upstream.localdevices
    @socket.on 'message', @upstream.message
    @socket.on 'mydevices', @upstream.mydevices
    @socket.on 'register', @upstream.register
    @socket.on 'resetToken', @upstream.resetToken
    @socket.on 'revokeToken', @upstream.revokeToken
    @socket.on 'status', @upstream.status
    @socket.on 'subscribe', @upstream.subscribe
    @socket.on 'unclaimeddevices', @upstream.unclaimeddevices
    @socket.on 'unregister', @upstream.unregister
    @socket.on 'unsubscribe', @upstream.unsubscribe
    @socket.on 'update', @upstream.update

  doAuthenticate: (auth, callback) =>
    if !auth.uuid? && !auth.token? # no uuid or token
      return callback null, metadata: {code: 204}

    request =
      metadata:
        jobType: 'Authenticate'
        auth: auth

    @doJob request, callback

  _emitNotReady: (code, auth) =>
    @socket.emit 'notReady',
      uuid:  auth.uuid
      token: auth.token
      api: 'connect'
      status: code

module.exports = SocketIOHandler
