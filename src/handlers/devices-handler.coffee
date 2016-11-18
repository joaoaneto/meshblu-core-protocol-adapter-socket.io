_    = require 'lodash'
http = require 'http'

class DevicesHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data={}, callback=->) =>
    {uuid,token} = data
    auth = _.cloneDeep @auth
    if uuid? and token?
      auth =
        uuid: uuid
        token: token
      delete data.token

    if data.online?
      data.online = data.online == 'true'

    _.each data, (value, key) =>
      if value == 'null' || value == ''
        data[key] = $exists: false

    request =
      metadata:
        jobType: 'SearchDevices'
        auth: auth
        fromUuid: auth.uuid
      data: data
    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 200
      devices = JSON.parse response.rawData
      _.each devices, (device) =>
        delete device.token
      return callback {devices}

module.exports = DevicesHandler
