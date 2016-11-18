_    = require 'lodash'
http = require 'http'

class GetDevicePublicKeyHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data={}, callback=->) =>
    {uuid,token} = data
    auth = _.cloneDeep @auth
    if uuid? and token?
      auth =
        uuid: uuid
        token: token
      delete data.token
    request =
      metadata:
        jobType: 'GetDevicePublicKey'
        auth: auth
        toUuid: data.uuid
        fromUuid: auth.uuid

    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 200
      data = JSON.parse response.rawData
      return callback data

module.exports = GetDevicePublicKeyHandler
