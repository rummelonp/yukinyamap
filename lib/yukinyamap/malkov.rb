# -*- coding: utf-8 -*-

module Yukinyamap
  class Malkov
    MARKER_BEGIN = '__BEGIN__'
    MARKER_END   = '__END__'

    ALPHA        = /^[\w ]+$/
    NUMBER       = /^[\d ]+$/

    IGNORE_BRANCKETS      = /[\[\]{}‘’“”〈〉《》「」『』【】〔〕〘〙〚〛［］｛]/
    BRANCKETS             = /([（）\(\)]|#{IGNORE_BRANCKETS})/
    SIGN_WITHOUT_BRANKETS = /[!"\#$%&'*+,-.\/:;<=>?@\^`|~°　ー﹏！＊＋．／：；＜＞？～｡､･￣]/
    SIGN                  = /(#{SIGN_WITHOUT_BRANKETS}|#{BRANCKETS})/

    attr_reader :table

    def initialize(texts = nil)
      @table   = texts ? Table.new(texts) : Table.from_db
      @recent  = YM.config[:popular][:recent]
      @ranking = YM.config[:popular][:ranking]
    end

    def rotate(text)
      table.rotate(text)

      self
    end

    def generate
      send [:generate_random, :generate_popular].sample
    end

    def generate_random
      generate_from_first_node(table.first_node)
    end

    def generate_popular
      generate_from_word(popular_word)
    end

    def generate_from_word(word)
      node = table.find_node(word)
      if node
        generate_from_last_node(node) + generate_from_first_node(node)
      else
        nil
      end
    end

    def generate_from_first_node(node)
      text = node.join
      loop do
        node = table.next_node(node)
        break unless node
        break if clean(text + node[2]).size > 140
        text += node[2]
        break if node[2] == MARKER_END
      end

      clean(text)
    end

    def generate_from_last_node(node)
      text = ''
      loop do
        node = table.prev_node(node)
        break unless node
        break if node[0] == MARKER_BEGIN
        break if clean(node[0] + text).size > 140
        text = node[0] + text
      end

      clean(text)
    end

    def popular_word(words = nil)
      popular_words(words).take(@ranking).map(&:first).sample
    end

    def popular_words(words = nil)
      tagger = Natto::MeCab.new
      words = words ? words : table.nodes.take(@recent).flatten
      words.select { |w|
        w != MARKER_BEGIN &&
        w != MARKER_END &&
        !w.match(NUMBER) &&
        !w.match(SIGN) &&
        tagger.parse(w).match('名詞')
      }.reduce(Hash.new(0)) { |r, w|
        r[w] += 1
        r
      }.select { |_, c| c > 1 }.
        sort_by { |_, c| -c }
    end

    private
    def clean(text)
      text.
        gsub(MARKER_BEGIN, '').
        gsub(MARKER_END, '').
        gsub(IGNORE_BRANCKETS, '').
        gsub(/ +/, ' ').
        strip
    end

    class Table
      DB_SELECTOR = {
        'text' => {'$exists' => true},
        'user.protected' => false,
        'user.screen_name' => {'$ne' => YM.screen_name}
      }.freeze
      DB_OPTIONS = {
        :limit => 3200,
        :sort => ['_id', :desc]
      }.freeze

      attr_reader :nodes

      def self.from_db
        new YM.collection('status').
          find(DB_SELECTOR, DB_OPTIONS).
          to_a.map {|s| s['text']}
      end

      def initialize(texts = [])
        @nodes = texts.map {|n| normalize(n)}
      end

      def flat_nodes
        nodes.flatten(1)
      end

      def rotate(text)
        return self unless text

        nodes.pop
        nodes.unshift normalize(text)

        self
      end

      def first_nodes
        flat_nodes.select { |n| n[0] == MARKER_BEGIN }
      end

      def prev_nodes(node)
        flat_nodes.select { |n| n[1] == node[0] && n[2] == node[1] }
      end

      def next_nodes(node)
        flat_nodes.select { |n| n[0] == node[1] && n[1] == node[2] }
      end

      def find_nodes(word)
        flat_nodes.select { |n| n.include?(word) }
      end

      def first_node
        first_nodes.sample
      end

      def prev_node(node)
        prev_nodes(node).sample
      end

      def next_node(node)
        next_nodes(node).sample
      end

      def find_node(word)
        find_nodes(word).sample
      end

      private
      def normalize(text)
        text = Cleaner.clean(text)
        node = YM.tagger.parse(text).split(' ')
        node = node.map do |n|
          (n.match(ALPHA) || n.match(NUMBER)) ? " #{n} " : n
        end
        [MARKER_BEGIN, *node, MARKER_END].each_cons(3).to_a
      end
    end

    module Cleaner
      USER_PATTERN    = /@[\w_]+/
      RT_PATTERN      = /(RT|QT):? #{USER_PATTERN}.*(\n|$)/
      HASHTAG_PATTERN = /#[\wＡ-Ｚａ-ｚ０-９ぁ-ヶ亜-黑]+/
      URL_PATTERN     = URI.regexp

      PATTERNS = [
        RT_PATTERN,
        USER_PATTERN,
        HASHTAG_PATTERN,
        URL_PATTERN
      ].freeze

      CHARACTER_REFERENCES = [
        {from: '&amp;', to: '&'},
        {from: '&lt;',  to: '<'},
        {from: '&gt;',  to: '>'},
      ].freeze

      def self.clean(text)
        PATTERNS.each do |r|
          text = text.gsub(r, '')
        end

        CHARACTER_REFERENCES.each do |r|
          text = text.gsub(r[:from], r[:to])
        end

        text
      end
    end
  end
end
