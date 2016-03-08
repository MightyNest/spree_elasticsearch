module Spree
  BaseHelper.class_eval do
    # parses the properties aggregation result
    # input: Facet(name: "properties", type: "terms", body: {"terms" => [{"term" => "key1||value1", "count" => 1},{"term" => "key1||value2", "count" => 1}]}])
    # output: Facet(name: key1, type: terms, body: {"terms" => [{"term" => "value1", "count" => 1},{"term" => "value2", "count" => 1}]})
    def expand_properties_facet_to_facet_array(aggregation)
      # first step is to build a hash
      # {"property_name" => [{"term" => "value1", "count" => 1},{"term" => "value2", "count" => 1}]}}
      property_names = {}
      aggregation["buckets"].each do |bucket|
        t = bucket["key"].split("||")
        property_name = t[0]
        property_value = t[1]
        # add a search_term to each term hash to allow searching on the element later on
        property = {"term" => property_value, "count" => bucket["doc_count"], "search_term" => bucket["key"]}
        if property_names.has_key?(property_name)
          property_names[property_name] << property
        else
          property_names[property_name] = [property]
        end
      end
      # next step is to transform the hash to facet objects
      # this allows us to handle it in a uniform way
      # format: Facet(name: "property_name", type: type, body: {"terms" => [{"term" => "value1", "count" => 1},{"term" => "value2", "count" => 1}]}])
      result = {}
      property_names.each do |key,value|
        value.sort_by!{|h| [-h["count"],h["term"].downcase]} # first sort on desc, then on term asc
        # result << Spree::Search::Elasticsearch::Facet.new(name: key, search_name: facet.name, type: facet.type, body: {"terms" => value})
        result[key] = {
          '_type' => 'terms',
          'terms' => value
        }
      end
      result
    end

    # Helper method for interpreting aggregation from Elasticsearch. Something like a before filter.
    # Sorting, changings things, the world is your oyster
    # Input is a hash
    def process_facets(aggregations)
      new_aggregation = {}
      delete_keys = []
      aggregations.map do |key, aggregation|
        if key == "properties"
          new_aggregation.merge! expand_properties_facet_to_facet_array(aggregation)
          delete_keys << :properties
        else
          aggregation
        end
      end
      delete_keys.each {|key| aggregations.delete(key) }
      aggregations.merge! new_aggregation
    end
  end
end