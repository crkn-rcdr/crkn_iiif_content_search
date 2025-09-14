# frozen_string_literal: true
class IiifContentSearchResponse
  attr_reader :search, :controller
  delegate :request, to: :controller

  def initialize(search, controller)
    @search = search
    @controller = controller
  end

  def as_json(*)
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
    docs = search.docs_by_id # <-- NEW

    search.highlights.each do |id, highlights|
      doc = docs[id]
      next unless doc # (shouldn’t happen if fl included id)

      highlights.each do |hl|
        hl.to_enum(:scan, %r{<em>.*?</em>}).each do
          resource = Resource.new(id, Regexp.last_match, doc)  # <-- pass doc
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
    require 'json'

    attr_reader :manifestid, :canvasid, :highlight, :ocrtext, :bbox_map

    def initialize(id, highlight_match, doc)
      @manifestid, @canvasid = id.split('|', 2)
      @highlight = strip_em(highlight_match.to_s)
      @ocrtext   = Array(doc['ocrtext']).first.to_s
      @bbox_map  = parse_bbox(Array(doc['ocrbbox']).first)
      @by_start  = build_by_start(@bbox_map) # start_offset => [[len, xywh], ...] (shortest first)
    end

    def annotations
      tokens.map do |chars, xywh|
        {
          id: annotation_url(chars, xywh),
          type: "Annotation",
          motivation: "highlighting",
          body: { type: "TextualBody", value: chars, format: "text/plain" },
          target: canvas_fragment_url(xywh)
        }
      end
    end

    private

    # --- sidecar parsing ---
    def parse_bbox(json_str)
      return {} if json_str.blank?
      a = JSON.parse(json_str)['a'] rescue []
      h = {}
      a.each_slice(6) do |s, l, x, y, w, hh|
        h[[s, l]] = "#{x},#{y},#{w},#{hh}"
      end
      h
    end

    def build_by_start(map)
      h = Hash.new { |hh, k| hh[k] = [] }
      map.each { |(s, l), xy| h[s] << [l, xy] }
      h.each_value { |arr| arr.sort_by!(&:first) }
      h
    end

    # --- tolerant mapping: exact → same-start-longer (punctuation) → tiny shift ---
    def lookup_xywh(idx, wlen)
      return bbox_map[[idx, wlen]] if bbox_map.key?([idx, wlen])

      if (cands = @by_start[idx]).present?
        cand = cands.find { |(l, _)| l >= wlen } || cands.last
        return cand.last if cand
      end

      [idx - 1, idx + 1, idx - 2, idx + 2].each do |j|
        next if j.negative?
        c = @by_start[j]
        next unless c&.any?
        min_len = [wlen - (idx - j).abs, 1].max
        cand = c.find { |(l, _)| l >= min_len } || c.last
        return cand.last if cand
      end
      "0,0,0,0"
    end

    # find each word of the <em>…</em> run in the stored text (same text used to build offsets)
    def tokens
      return [] if highlight.blank? || ocrtext.blank? || bbox_map.empty?
      words  = highlight.split(/\s+/).reject(&:blank?)
      out    = []
      cursor = 0
      words.each do |w|
        idx = ocrtext.index(w, cursor) || ocrtext.index(w) # fall back to first occurrence
        if idx
          out << [w, lookup_xywh(idx, w.length)]
          cursor = idx + w.length
        else
          out << [w, "0,0,0,0"]
        end
      end
      out
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

    def annotation_url(_chars, xywh)
      coords = URI.encode_www_form_component(xywh)
      "#{canvas_url}/text/at/#{coords}"
    end

    def strip_em(text)
      text.gsub(%r{</?em>}, "")
    end
  end
end
