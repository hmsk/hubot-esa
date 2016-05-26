Helper = require('hubot-test-helper')
chai = require 'chai'
nock = require 'nock'

expect = chai.expect

helper = new Helper('../src/esa.coffee')

describe 'esa', ->
  nockScope = null
  room = null

  beforeEach ->
    process.env.HUBOT_ESA_ACCESS_TOKEN = 'dummy'
    process.env.HUBOT_ESA_TEAM = 'ginger'
    process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM = 'general'
    # process.env.HUBOT_ESA_WEBHOOK_ENDPOINT = '/hubot/ginger'
    # process.env.HUBOT_ESA_WEBHOOK_JUST_EMIT = 'true'
    nock.disableNetConnect()
    nockScope = nock('https://api.esa.io')
    room = helper.createRoom()

  afterEach ->
    nock.cleanAll()
    room.destroy()

  describe 'get from api', ->
    context 'someone requests stats', ->
      beforeEach (done) ->
        nockScope
          .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/stats")
          .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
          .replyWithFile(200, "#{__dirname}/fixtures/stats.json")
        room.user.say('gingy', '@hubot esa stats')
        setTimeout done, 200

      it 'responds stats', ->
        expect(room.messages).to.eql [
          ['gingy', '@hubot esa stats']
          ['hubot', "Members: 20\nPosts: 1959\nComments: 2695\nStars: 3115\nDaily Active Users: 8\nWeekly Active Users: 14\nMonthly Active Users: 15"]
        ]

    describe 'post', ->
      context 'in own team', ->
        beforeEach ->
          nockScope
            .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/posts/1390")
            .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
            .replyWithFile(200, "#{__dirname}/fixtures/post.json")

        context 'someone says post url', ->
          beforeEach (done) ->
            room.user.say('gingy', 'https://ginger.esa.io/posts/1390')
            setTimeout done, 200

          it 'send message about post', ->
            expect(room.messages).to.eql [
              ['gingy', 'https://ginger.esa.io/posts/1390']
              ['hubot', 'esa: 日報/2015/05/09/hi! #api #dev']
            ]

        context 'someone says post url wtih anchor', ->
          beforeEach (done) ->
            room.user.say('gingy', 'https://ginger.esa.io/posts/1390#1-1-1')
            setTimeout done, 200

          it 'send message about post', ->
            expect(room.messages).to.eql [
              ['gingy', 'https://ginger.esa.io/posts/1390#1-1-1']
              ['hubot', 'esa: 日報/2015/05/09/hi! #api #dev']
            ]

      context 'in other team, someone says post url', ->
        beforeEach (done) ->
          room.user.say('gingy', 'https://zachary.esa.io/posts/1390')
          setTimeout done, 200

        it 'nothing to say', ->
          expect(room.messages).to.eql [
            ['gingy', 'https://zachary.esa.io/posts/1390']
          ]

    describe 'comment', ->
      context 'in own team', ->
        beforeEach (done) ->
          nockScope
            .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/comments/2121")
            .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
            .replyWithFile(200, "#{__dirname}/fixtures/comment.json")
          room.user.say('gingy', 'https://ginger.esa.io/posts/1390#comment-2121')
          setTimeout done, 200

        it 'send message about comment', ->
          expect(room.messages).to.eql [
            ['gingy', 'https://ginger.esa.io/posts/1390#comment-2121']
            ['hubot', 'esa: 読みたい']
          ]

      context 'in other team, someone says comment url', ->
        beforeEach (done) ->
          room.user.say('gingy', 'https://zachary.esa.io/posts/1390#comment-2121')
          setTimeout done, 200

        it 'nothing to say', ->
          expect(room.messages).to.eql [
            ['gingy', 'https://zachary.esa.io/posts/1390#comment-2121']
          ]
