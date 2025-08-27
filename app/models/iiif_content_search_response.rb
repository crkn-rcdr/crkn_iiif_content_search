# frozen_string_literal: true
class IiifContentSearchResponse
  attr_reader :search, :controller

  delegate :request, to: :controller

  def initialize(search, controller)
    @search = search
    @controller = controller
  end

  def as_json(*_args)
    {
      "@context": "http://iiif.io/api/search/2/context.json",
      id: base_service_url,
      type: "AnnotationPage",
      items: resources.flat_map(&:annotations),
      next: next_page_url_if_needed
    }.compact
  end

  private

  def base_service_url
    "https://crkn-iiif-content-search.azurewebsites.net/search/#{search.id}"
  end

  def next_page_url_if_needed
    return unless next_page?

    "#{base_service_url}?start=#{search.start + search.rows}&q=#{URI.encode_www_form_component(search.q)}"
  end

  def resources
    return to_enum(:resources) unless block_given?

    seen_ids = Set.new
    search.highlights.each do |id, highlights|
      highlights.each do |highlight|
        highlight.to_enum(:scan, %r{<em>.*?</em>}).each do
          resource = Resource.new(id, Regexp.last_match)
          resource.annotations.each do |anno|
            next if seen_ids.include?(anno[:id])
            seen_ids.add(anno[:id])
            yield resource
          end
        end
      end
    end
  end

  def next_page?
    search.num_found.to_i > (search.start.to_i + search.rows.to_i)
  end

  class Resource
    attr_reader :manifestid, :canvasid, :highlight

    def initialize(id, highlight)
      @manifestid, @canvasid = id.split("|", 2)
      @highlight = strip_em(highlight.to_s)
    end

    def annotations
      tokens.map do |chars, xywh|
        {
          id: annotation_url(chars, xywh),
          type: "Annotation",
          motivation: "highlighting",
          body: {
            type: "TextualBody",
            value: chars,
            format: "text/plain"
          },
          target: canvas_fragment_url(xywh)
        }
      end
    end

    private

    def tokens
      highlight.split.map { |x| split_word_and_payload(x) }
    end

    def split_word_and_payload(x)
      x.include?("☞") ? x.split("☞") : [x, "0,0,0,0"]
    end

    def canvas_fragment_url(xywh)
      "#{canvas_url}#xywh=#{xywh.split(',').map(&:to_i).join(',')}"
    end

    def canvas_url
      if @manifestid.start_with?('http://', 'https://')
        "#{@manifestid}/canvas/#{@canvasid}"
      else
        "https://crkn-iiif-api.azurewebsites.net/manifest/#{@manifestid}/canvas/#{@canvasid}"
      end
    end

    def annotation_url(chars, xywh)
      coords = URI.encode_www_form_component(xywh)
      "#{canvas_url}/text/at/#{coords}"
    end

    def strip_em(text)
      text.gsub(%r{</?em>}, "")
    end
  end
end
