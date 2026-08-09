# frozen_string_literal: true

module Wajub
  class PagedResult
    attr_reader :data, :meta, :has_more

    def initialize(data:, meta:, has_more:, fetch_page:)
      @data = data
      @meta = meta
      @has_more = has_more
      @fetch_page = fetch_page
    end

    def next_page
      raise WajubError.new('no more pages available', code: 'pagination_error', http_status: 0) unless @has_more

      current = @meta&.fetch('current_page', 1).to_i
      @fetch_page.call(current + 1)
    end

    def auto_paging_each(&block)
      page = self
      loop do
        page.data.each(&block)
        break unless page.has_more

        page = page.next_page
      end
    end

    def self.create(client, path, plural_key, params = nil)
      params ||= {}
      fetch = lambda do |page_num|
        query = params.merge('page' => page_num)
        res = client.get(path, query)
        list = HttpUtils.pick_list(res, plural_key)
        meta = list[:meta]
        has_more = false
        if meta
          current = meta['current_page'].to_i
          last = meta['last_page'].to_i
          has_more = current < last if current.positive? && last.positive?
        end
        new(data: list[:data], meta: meta, has_more: has_more, fetch_page: fetch)
      end

      page = params['page'] || params[:page] || 1
      fetch.call(page.to_i)
    end
  end
end
