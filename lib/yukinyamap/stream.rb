# -*- coding: utf-8 -*-

module Yukinyamap
  class Stream
    def initialize
      setup
    end

    def setup
      @client = YM.user_stream
      @hooks  = YM.constants.
        grep(/Hook$/).
        map { |c| YM.const_get(c).new }
    end

    def start
      loop do
        begin
          @client.user do |status|
            @hooks.each do |h|
              h.match(status) && h.call(status) rescue YM.tee $!, :warn
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
