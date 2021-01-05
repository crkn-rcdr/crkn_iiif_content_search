# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifContentSearchResponse, type: :controller do
  controller(SearchController) do
    # no-op.
  end

  subject(:response) { described_class.new(search, controller) }

  let(:search) { instance_double(Search, id: 'x', highlights: highlights, num_found: 10, start: 0, rows: 10) }
  let(:highlights) do
    {
      'x/y/alto_with_coords' => ['<em>George☞639,129,79,243 Stirling’s☞633,426,84,300</em> Heritage☞632,789,84,291'],
      'x/y/alto_with_intermediates' => ['<em>George☞639,129,79,243</em> Emerson’s☞633,426,84,300
<em>Heritage☞632,789,84,291</em><em>George☞639,129,79,243</em>
Emerson’s☞633,426,84,300 <em>Heritage☞632,789,84,291</em>
Endcap☞632,789,84,291'],
      'x/y/alto_multiline_coords' => ['<em>George☞639,129,79,243 Stirling’s☞732,0,84,291</em>'],
      'x/y/text_without_coords' => ['<em>MEMBERS</em> OF THE COUNCIL']
    }
  end

  describe '#before' do
    context 'with truncated coordinate payloads in the highlight' do
      let(:highlights) do
        {
          'x/truncated_highlight_coords/alto' => ['0,2 George☞639,129,79,243 <em>Stirling’s☞633,426,84,300</em>']
        }
      end

      it 'strips leading payload fragments' do
        expect(response.resources.first.before).to eq 'George'
      end
    end
  end

  describe '#match' do
    context 'with truncated coordinate payloads in the highlight' do
      let(:highlights) do
        {
          'x/truncated_highlight_coords/alto' => ['0,2 George☞639,129,79,243 <em>Stirling’s☞633,426,84,300</em>']
        }
      end

      it 'strips leading payload fragments' do
        expect(response.resources.first.match).to eq 'Stirling’s'
      end
    end
  end

  describe '#as_json' do
    it 'has the expected json-ld properties' do
      expect(response.as_json).to include "@context": ['http://iiif.io/api/presentation/2/context.json',
                                                       'http://iiif.io/api/search/1/context.json'],
                                          "@id": 'http://test.host',
                                          "@type": 'sc:AnnotationList'
    end

    it 'has resources for each word in the alto highlight' do
      expect(response.as_json).to include resources: include("@id": 'https://purl.stanford.edu/x/iiif/canvas/y/text/at/639,129,79,243',
                                                             "@type": 'oa:Annotation',
                                                             "motivation": 'sc:painting',
                                                             "resource": {
                                                               "@type": 'cnt:ContentAsText',
                                                               "chars": 'George'
                                                             },
                                                             "on": 'https://purl.stanford.edu/x/iiif/canvas/y#xywh=639,129,79,243')

      expect(response.as_json).to include resources: include("@id": 'https://purl.stanford.edu/x/iiif/canvas/y/text/at/633,426,84,300',
                                                             "@type": 'oa:Annotation',
                                                             "motivation": 'sc:painting',
                                                             "resource": {
                                                               "@type": 'cnt:ContentAsText',
                                                               "chars": 'Stirling’s'
                                                             },
                                                             "on": 'https://purl.stanford.edu/x/iiif/canvas/y#xywh=633,426,84,300')
    end

    it 'has a resource for the plain text highlight' do
      expect(response.as_json).to include resources: include("@id": 'https://purl.stanford.edu/x/iiif/canvas/y/text/at/0,0,0,0',
                                                             "@type": 'oa:Annotation',
                                                             "motivation": 'sc:painting',
                                                             "resource": {
                                                               "@type": 'cnt:ContentAsText',
                                                               "chars": 'MEMBERS'
                                                             },
                                                             "on": 'https://purl.stanford.edu/x/iiif/canvas/y#xywh=0,0,0,0')
    end

    describe '#resources' do
      context 'with mixed emphasis solr responses' do
        let(:highlights) do
          {
            'x/y/alto_with_intermediates' => ['<em>George☞639,129,79,243</em> Emerson’s☞633,426,84,300
<em>Heritage☞632,789,84,291 Library☞639,129,79,243</em>
being☞633,426,84,300 <em>demolished☞632,789,84,291</em>
thursday☞632,789,84,291']
          }
        end

        it 'returns 3 resources' do
          expect(response.resources.to_a.length).to eq 3
        end

        it 'returns have multiple annotations if multiple words are emphasized' do
          expect(response.resources.to_a[0].annotations.length).to eq 1
          expect(response.resources.to_a[1].annotations.length).to eq 2
          expect(response.resources.to_a[2].annotations.length).to eq 1
        end

        it 'returns the expected annotation chars' do
          chars = response.resources.flat_map(&:annotations).map { |annotation| annotation[:resource][:chars] }
          expect(chars).to eq %w[George Heritage Library demolished]
        end
      end
    end

    context 'with results with slightly different highlights due to language-specific stemming differences' do
      let(:highlights) do
        {
          'zx429wp8334/zx429wp8334_35/36105115596277_0036.xml' => [
            '<em>flower☞855,685,96,27</em> of☞972,682,29,28 <em>flowers.☞1024,682,120,27</em>',
            '<em>flower☞855,685,96,27</em> of☞972,682,29,28 flowers.'
          ]
        }
      end

      it 'deduplicates based on the actual highlight and returns only 2 resources' do
        expect(response.as_json[:resources].length).to eq 2
        expect(response.as_json[:hits].length).to eq 2
      end
    end

    context 'with adjacent hits' do
      let(:highlights) do
        {
          '' => [
            'as☞1590.12,1094.11,46.81,33.89 <em>crimes☞1660.33,1094.11,140.42,3'\
            '3.89</em> <em>against☞1824.15,1094.11,163.82,33.89</em> <em>humani'\
            'ty,☞2011.38,1094.11,210.62,33.89</em> contrary☞674.90,1140.00,179.'\
            '61,32.48 to☞899.41,1140.00,44.90,32.48'
          ]
        }
      end

      it 'combines together into a single hit' do
        expect(response.resources.to_a[0].match).to eq 'crimes against humanity,'
      end
    end

    it 'has hits with additional context for an ALTO resource' do
      expect(response.as_json).to include hits: include("@type": 'search:Hit',
                                                        "annotations": [
                                                          'https://purl.stanford.edu/x/iiif/canvas/y/text/at/639,129,79,243',
                                                          'https://purl.stanford.edu/x/iiif/canvas/y/text/at/633,426,84,300'
                                                        ],
                                                        "before": '',
                                                        "after": 'Heritage',
                                                        "match": 'George Stirling’s')
    end

    it 'has hits with additional context for a plain text resource' do
      expect(response.as_json).to include hits: include("@type": 'search:Hit',
                                                        "annotations": [
                                                          'https://purl.stanford.edu/x/iiif/canvas/y/text/at/0,0,0,0'
                                                        ],
                                                        "before": '',
                                                        "after": 'OF THE COUNCIL',
                                                        "match": 'MEMBERS')
    end

    it 'has basic pagination context' do
      expect(response.as_json).to include within: include('@type': 'sc:Layer',
                                                          first: ending_with('start=0'),
                                                          last: ending_with('start=0'))
    end

    context 'with a next page' do
      let(:search) { instance_double(Search, id: 'x', highlights: highlights, num_found: 17, start: 0, rows: 10) }

      it 'has pagination context' do
        expect(response.as_json).to include next: ending_with('start=10'),
                                            within: include('@type': 'sc:Layer',
                                                            first: ending_with('start=0'),
                                                            last: ending_with('start=10'))
      end
    end

    context 'with a start offset' do
      let(:search) { instance_double(Search, id: 'x', highlights: highlights, num_found: 17, start: 10, rows: 10) }

      it 'has pagination context' do
        expect(response.as_json).to include within: include('@type': 'sc:Layer',
                                                            first: ending_with('start=0'),
                                                            last: ending_with('start=10'))
      end
    end
  end
end
