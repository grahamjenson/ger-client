q = require 'q'

qhttp = require 'q-io/http'

FormData = require('form-data');
Readable = require('stream').Readable;

parse_response_into_json_status = (response) ->
  q.all([response.body.read(), response.status])
  .spread( (body, status) ->
    json = JSON.parse(body.toString())
    [json, status]
  )

class GERClient
  constructor : (@server_uri, @tenant_id) ->

  event: (person, action, thing, session) ->
    req = { 
      method: "POST", 
      body: [JSON.stringify({person: person, action: action, thing: thing, session: session})], 
      url: "#{@server_uri}/tenant/#{@tenant_id}/events"
    }
    qhttp.request(req)
    .then(parse_response_into_json_status)

  get_event: (person, action, thing) ->
    url = "#{@server_uri}/tenant/#{@tenant_id}/events?"
    params = []
    params.push "person=#{person}" if person
    params.push "action=#{action}" if action
    params.push "thing=#{thing}" if thing
    url += params.join('&')
    req = { method: "GET", url: url}
    qhttp.request(req)
    .then(parse_response_into_json_status)

  action: (action, weight) ->
    req = { method: "PUT", body: [JSON.stringify({weight: weight})], url: "#{@server_uri}/tenant/#{@tenant_id}/actions/#{action}"}
    qhttp.request(req)
    .then(parse_response_into_json_status)

  get_action: (action) ->
    req = { method: "GET", url: "#{@server_uri}/tenant/#{@tenant_id}/actions/#{action}"}
    qhttp.request(req)
    .then(parse_response_into_json_status)

  recommendations_for_person: (person, action) ->
    req = { method: "GET", url: "#{@server_uri}/tenant/#{@tenant_id}/recommendations?person=#{person}&action=#{action}"}
    qhttp.request(req)
    .then(parse_response_into_json_status)

  bootstrap: (stream) ->
    body_promise = q.defer()
    status_promise = q.defer()
    form = new FormData();
    form.append('events', stream, {filename: 'file.csv', contentType: 'text/csv' })
    form.submit("#{@server_uri}/tenant/#{@tenant_id}/events/bootstrap", (err, resp) ->
      if err
        status_promise.reject(err)
        body_promise.reject(err)
      else
        status_promise.resolve(resp.statusCode)
        resp.on('data', (chunk) ->
          body_promise.resolve( JSON.parse(chunk) )
        )
    )

    q.all( [ body_promise.promise, status_promise.promise])

  get_event_stats: ->
    req = { method: "GET", url: "#{@server_uri}/tenant/#{@tenant_id}/events/stats"}
    qhttp.request(req)
    .then(parse_response_into_json_status)

  compact_database: () ->
    req = { method: "POST", body: [], url: "#{@server_uri}/tenant/#{@tenant_id}/compact"}
    qhttp.request(req)
    .then(parse_response_into_json_status)

#AMD
if (typeof define != 'undefined' && define.amd)
  define([], -> return GERClient)
#Node
else if (typeof module != 'undefined' && module.exports)
    module.exports = GERClient;
