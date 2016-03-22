_    = require 'lodash'
http = require 'http'

class MyDevicesHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data={}, callback=->) =>
    {uuid,token} = data
    auth = _.cloneDeep @auth
    if uuid? and token?
      auth =
        uuid: uuid
        token: token
      delete data.token
    data.owner = auth.uuid
    request =
      metadata:
        jobType: 'SearchDevices'
        auth: auth
        fromUuid: auth.uuid
      data: data
    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 200
      devices = JSON.parse response.rawData
      _.each devices, (device) =>
        delete device.token
      return callback {devices}

module.exports = MyDevicesHandler
