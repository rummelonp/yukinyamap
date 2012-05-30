# -*- coding: utf-8 -*-

module Yukinyamap
  class Stream
    def initialize
      setup
    end

    def setup
      @client = YM.user_stream
      @hooks  = []
      @hooks  << MongoHook.new
      @hooks  << LogHook.new
      @hooks  << StoreHook.new
      @hooks  << TweetHook.new
      @hooks  << ReplyHook.new
      @hooks  << FollowHook.new
    end

    def start
      loop do
        begin
          @client.user do |status|
            @hooks.each do |h|
              h.call(status) rescue YM.tee $!, :warn
            end
          end
        rescue UserStream::Unauhtorized
          YM.tee $!, :error
          raise SystemExit
        rescue
          YM.tee $!, :error
        end
        sleep 1
      end
    end
  end
end
