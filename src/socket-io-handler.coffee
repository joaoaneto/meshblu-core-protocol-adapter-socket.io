_                                     = require 'lodash'
async                                 = require 'async'
http                                  = require 'http'
AuthenticateHandler                   = require './handlers/authenticate-handler'
ClaimDeviceHandler                    = require './handlers/claimdevice-handler'
GetDeviceHandler                      = require './handlers/get-device-handler'
GetDevicePublicKeyHandler             = require './handlers/get-device-public-key-handler'
ResetTokenHandler                     = require './handlers/reset-token-handler'
DevicesHandler                        = require './handlers/devices-handler'
IdentityAuthenticateHandler           = require './handlers/identity-authenticate-handler'
GetAuthorizedSubscriptionTypesHandler = require './handlers/get-authorized-subscription-types-handler'
CreateSessionTokenHandler             = require './handlers/create-session-token-handler'
MyDevicesHandler                      = require './handlers/mydevices-handler'
RegisterDeviceHandler                 = require './handlers/register-device-handler'
RevokeSessionTokenHandler             = require './handlers/revoke-session-token-handler'
RevokeTokenByQueryHandler             = require './handlers/revoke-token-by-query-handler'
SendMessageHandler                    = require './handlers/send-message-handler'
StatusHandler                         = require './handlers/status-handler'
UnregisterDeviceHandler               = require './handlers/unregister-device-handler'
UpdateAsHandler                       = require './handlers/update-as-handler'
UpdateHandler                         = require './handlers/update-handler'
WhoamiHandler                         = require './handlers/whoami-handler'

class SocketIOHandler
  constructor: ({@socket,@jobManager,@messengerManagerFactory}) ->

  handlerHandler: (handlerClass) =>
    (data, callback=->) => # Providing default callback cause it comes from the API consumer
      return callback() unless @auth?
      requestQueue = 'request'
      responseQueue = 'response'
      handler = new handlerClass {@jobManager, @auth, requestQueue, responseQueue}
      handler.do data, callback

  initialize: =>
    @socket.on 'authenticate', @handlerHandler AuthenticateHandler
    @socket.on 'claimdevice', @handlerHandler ClaimDeviceHandler
    @socket.on 'device', @handlerHandler GetDeviceHandler
    @socket.on 'devices', @handlerHandler DevicesHandler
    @socket.on 'disconnect', @onDisconnect
    @socket.on 'identity', @onIdentity
    @socket.on 'getPublicKey', @handlerHandler GetDevicePublicKeyHandler
    @socket.on 'generateAndStoreToken', @handlerHandler CreateSessionTokenHandler
    @socket.on 'message', @handlerHandler SendMessageHandler
    @socket.on 'mydevices', @handlerHandler MyDevicesHandler
    @socket.on 'register', @handlerHandler RegisterDeviceHandler
    @socket.on 'resetToken', @handlerHandler ResetTokenHandler
    @socket.on 'revokeToken', @handlerHandler RevokeSessionTokenHandler
    @socket.on 'revokeTokenByQuery', @handlerHandler RevokeTokenByQueryHandler
    @socket.on 'status', @handlerHandler StatusHandler
    @socket.on 'subscribe', @onSubscribe
    @socket.on 'unregister', @handlerHandler UnregisterDeviceHandler
    @socket.on 'unsubscribe', @onUnsubscribe
    @socket.on 'update', @handlerHandler UpdateHandler
    @socket.on 'updateas', @handlerHandler UpdateAsHandler
    @socket.on 'whoami', @handlerHandler WhoamiHandler

    @messenger = @messengerManagerFactory.build()

    @messenger.on 'error', (error) =>
      @_emitNotReady 500
      @messenger.close()

    @messenger.on 'message', (channel, message) =>
      @socket.emit 'message', message

    @messenger.on 'config', (channel, message) =>
      @socket.emit 'config', message

    @messenger.on 'data', (channel, message) =>
      @socket.emit 'data', message

    @messenger.connect =>
      @socket.emit 'identify'

  onDisconnect: =>
    @messenger?.close()
    @_setOffline() unless @auth?.auto_set_online == false

  onIdentity: (auth) =>
    return @_autoRegister auth unless auth.uuid? && auth.token?

    @auth = _.pick auth, 'uuid', 'token', 'auto_set_online'
    authenticate = @handlerHandler IdentityAuthenticateHandler
    authenticate @auth, (error, response) =>
      return @_emitNotReady 504, @auth if error?
      return @_emitNotReady 401, @auth unless response.metadata.code == 204

      @_setOnline() unless @auth.auto_set_online == false
      @_emitReady()

  onSubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    data.types.push 'data'
    data.types.push 'config'
    requestQueue = 'request'
    responseQueue = 'response'

    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, @auth, requestQueue, responseQueue}
    handler.do data, (response) =>
      async.each response.types, (type, next) =>
        @messenger.subscribe {type, uuid: data.uuid}, next

  onUnsubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    requestQueue = 'request'
    responseQueue = 'response'

    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, @auth, requestQueue, responseQueue}
    handler.do data, (response) =>
      async.each response.types, (type, next) =>
        @messenger.unsubscribe {type, uuid: data.uuid}, next

  _autoRegister: (auth) =>
    {auto_set_online} = auth
    @auth = auth
    register = @handlerHandler RegisterDeviceHandler
    data = _.cloneDeep auth
    delete data.auto_set_online
    register data, (response) =>
      @_emitNotReady 500, auth unless response?
      @auth = response
      @auth.auto_set_online = auto_set_online

      @_setOnline() unless @auth.auto_set_online == false
      @_emitReady()

  _setOnline: =>
    return unless @auth?.uuid?
    @_updateDevice {uuid: @auth.uuid, online: true}
    @_sendDeviceStatusMessage online: true

  _setOffline: =>
    return unless @auth?.uuid?
    @_updateDevice {uuid: @auth.uuid, online: false}
    @_sendDeviceStatusMessage online: false

  _updateDevice: (data) =>
    update = @handlerHandler UpdateHandler
    update data, ->

  _sendDeviceStatusMessage: (data) =>
    message =
      devices: '*'
      topic: 'device-status'
      payload: data
    sendMessage = @handlerHandler SendMessageHandler
    sendMessage message, ->

  _emitReady: (data) =>
    async.each ['received', 'config', 'data'], (type, next) =>
      @messenger.subscribe {type, uuid: @auth.uuid}, next

    @socket.emit 'ready', {api: 'connect', status: 201, uuid: @auth.uuid, token: @auth.token}

  _emitNotReady: (code, auth={}) =>
    @socket.emit 'notReady',
      uuid:  auth.uuid
      token: auth.token
      api: 'connect'
      status: code

module.exports = SocketIOHandler
