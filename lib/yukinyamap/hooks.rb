# -*- coding: utf-8 -*-

module Yukinyamap
  class MongoHook
    def match(status)
      true
    end

    def call(status)
      if status.text
        status.keywords = YM.tagger.parse(status.text).split(' ')
      end
      YM.collection(YM.col_key_from_status(status)).insert(status)
    end
  end

  class LogHook
    def match(status)
      true
    end

    def call(status)
      key = YM.col_key_from_status(status)
      message = key
      if key == 'status'
        message += ": @#{status.user!.screen_name}"
      end
      YM.tee message, :debug
    end
  end

  class StoreHook
    def match(status)
      status.user!.screen_name != YM.screen_name &&
        status.text &&
        !status.protected?
    end

    def call(status)
      YM.malkov.rotate(status.text)
    end
  end

  class TweetHook
    def initialize
      @tweet_count = 0
      @update_time = Time.now

      @min_count   = YM.config[:tweet][:min][:count]
      @min_minutes = YM.config[:tweet][:min][:minutes].minutes
      @max_count   = YM.config[:tweet][:max][:count]
      @max_minutes = YM.config[:tweet][:max][:minutes].minutes
    end

    def match(status)
      status.user!.screen_name != YM.screen_name &&
        status.in_reply_to_screen_name != YM.screen_name
    end

    def call(status)
      @tweet_count += 1
      diff = Time.now.to_i - @update_time.to_i
      if diff > @max_minutes ||
          @tweet_count > @max_count ||
          (@tweet_count > @min_count && diff > @min_minutes)
        @tweet_count = 0
        @update_time = Time.now
        YM.twitter.update(YM.malkov.generate)
      end
    end
  end

  class ReplyHook
    def match(status)
      status.user!.screen_name != YM.screen_name &&
        status.in_reply_to_screen_name == YM.screen_name
    end

    def call(status)
      options = {:in_reply_to_status_id => status.id}
      tweet = "@#{status.user.screen_name} #{YM.malkov.generate}"
      YM.twitter.update(tweet, options)
    end
  end

  class FollowHook
    def match(status)
      status.event == 'follow' &&
        status.source.screen_name != YM.screen_name
    end

    def call(status)
      YM.twitter.follow(status.source.screen_name)
      tweet = "@#{status.source.screen_name} #{YM.malkov.generate}"
      YM.twitter.update(tweet)
    end
  end
end

Dir[YM.root + '/hooks/**.rb'].each { |f| require f }
