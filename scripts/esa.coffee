# Descriptipn
#   Hubot script handle webhook and API of https://esa.io
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_ESA_ACCESS_TOKEN
#   HUBOT_ESA_TEAM_NAME
#   HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
#   HUBOT_ESA_WEBHOOK_IGNORE_DIRECTORY
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

handleWebhook = (payload) ->
  # https://docs.esa.io/posts/37
  switch payload.kind
    when 'post_create'
      return "#{payload.user.screen_name} created a new post: #{if payload.post.wip then '(WIP) ' else ''}#{payload.post.name}\n>#{payload.post.message}\n#{payload.post.url}"
    when 'post_update'
      return "#{payload.user.screen_name} updated the post: #{if payload.post.wip then '(WIP) ' else ''}#{payload.post.name}\n>#{payload.post.message}\n#{payload.post.url}"
    when 'post_archive'
      return "#{payload.user.screen_name} archived the post: #{payload.post.name}\n#{payload.post.url}"
    when 'comment_create'
      return "#{payload.user.screen_name} posted a comment to #{payload.post.name}\n>#{payload.comment.body_md.replace("\n",'')}\n#{payload.post.url}"
    when 'member_join'
      return "New member joined: #{payload.name}(#{payload.screen_name})"
    else
      robot.logger.warning "Unknown Webhook received"
      return "Unknown Webhook received"

class EsaClientRobot
  constructor: (@robot, @team, @access_token) ->
    unless @team then @robot.logger.warning "HUBOT_ESA_TEAM_NAME is not set."
    unless @team then @robot.logger.warning "HUBOT_ESA_ACCESS_TOKEN is not set."

  baseUrl: ->
    "https://api.esa.io/v1/teams/#{@team}"

  getRequest: (path, callback) ->
    @robot.http("#{@baseUrl()}#{path}").query({access_token: @access_token}).get() (error, response, body) ->
      if response.statusCode is 200
        callback(JSON.parse(body))
      else
        @robot.logger.warning "esa API GET request failed: #{error}"

module.exports = (robot) ->
  esa = new EsaClientRobot(robot, process.env.HUBOT_ESA_TEAM_NAME, process.env.HUBOT_ESA_ACCESS_TOKEN)
  robot.router.post '/hubot/esa', (req, res) ->
    res.writeHead(204)
    res.end()
    unless process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
      robot.logger.warning "HUBOT_ESA_WEBHOOK_DEFAULT_ROOM is not set."
      return
    unless req.headers['user-agent'] == 'esa-Hookshot/v1'
      robot.logger.warning "Requested unknown user agent: #{req.headers['user-agent']}"
      return
    robot.messageRoom process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM, handleWebhook(req.body or {})

  robot.respond /esa stats/, (res) ->
    esa.getRequest("/stats", (stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\b/, (res) ->
    unless res.match[1] == process.env.HUBOT_ESA_TEAM_NAME then return
    esa.getRequest("/posts/#{res.match[2]}", (post) ->
      res.send "esa: #{post.full_name}"
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\#comment-(\d+)/, (res) ->
    unless res.match[1] == process.env.HUBOT_ESA_TEAM_NAME then return
    esa.getRequest("/comments/#{res.match[3]}", (comment) ->
      res.send "#{comment.body_md}"
    )
