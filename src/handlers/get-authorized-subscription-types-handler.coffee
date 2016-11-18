_ = require 'lodash'
http = require 'http'

class GetAuthorizedSubscriptionTypesHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback) =>
    auth = _.cloneDeep @auth
    if data.token?
      auth =
        uuid: data.uuid
        token: data.token
      delete data.token

    request =
      metadata:
        jobType: 'GetAuthorizedSubscriptionTypes'
        toUuid: data.uuid
        auth: auth
      data: data

    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 204
      callback JSON.parse(response.rawData)

module.exports = GetAuthorizedSubscriptionTypesHandler
