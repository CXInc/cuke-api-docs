require 'virtus'
require 'arbre'
require 'json'
require 'deep_merge/rails_compat'

module Cucumber
  module Formatter
    class ApiDocs

      VERB_ORDER = %w(GET POST PUT PATCH DELETE)

      class Parameter
        include Virtus.model

        attribute :type, String
        attribute :name, String
        attribute :value, String
      end

      class Example
        include Virtus.model

        attribute :name, String
        attribute :prerequisites, Array[String]
        attribute :parameters, Array[Parameter]
        attribute :code, Integer
        attribute :content_type, String
        attribute :json_response, Hash, default: {}
      end

      class Group
        include Virtus.model

        attribute :key, String
        attribute :name, String

        def self.for_tag(tag)
          @groups ||= {}
          @groups[tag] ||= create(tag)
        end

        def self.create(tag)
          key = tag.gsub("@", "")
          name = key.gsub("_", " ").capitalize

          new(key: key, name: name)
        end
      end

      class Endpoint
        include Virtus.model

        attribute :description, String
        attribute :tag, String
        attribute :group, String
        attribute :verb, String
        attribute :path, String
        attribute :examples, Array[Example]
        attribute :parameters, Array[Parameter]

        def name
          "#{verb} #{path}"
        end

        def sort_order
          VERB_ORDER.index(verb) || fail("Unable to look up verb for #{name}")
        end
      end

      def initialize(step_mother, io, options)
        @endpoints = []
      end

      def after_features(features)
        write_html
      end

      def before_feature(feature)
        verb, path = feature.name.split(" ")
        @endpoint = Endpoint.new(verb: verb, path: path)
      end

      def after_feature(feature)
        @endpoint.parameters.uniq! { |parameter| parameter.name }
        @endpoints << @endpoint
      end

      def before_comment(comment)
        @endpoint.description = comment.to_sexp[1].gsub(/#\s*/, "")
      end

      def before_feature_element(feature_element)
        @example = Example.new(name: feature_element.title)
        @prior_keyword = nil
      end

      def after_feature_element(feature_element)
        @endpoint.examples << @example
      end

      def before_step(step)
        keyword = if step.keyword.strip == "And" && @prior_keyword
          @prior_keyword
        else
          step.keyword.strip
        end

        case keyword
        when "Given"
          @example.prerequisites << step.name
          @prior_keyword = "Given"
        when "When"
          if step.multiline_arg
            step.multiline_arg.rows.each do |type, name, value|
              @example.parameters << Parameter.new(type: type, name: name, value: value)
              @endpoint.parameters << Parameter.new(type: type, name: name)
            end
          end

          @prior_keyword = "When"
        when "Then"
          if matches = step.name.match(/the status code is (\d+)/)
            @example.code = matches[1]
          elsif matches = step.name.match(/Content-Type is (.*)$/)
            @example.content_type = matches[1]
          elsif matches = step.name.match(/the JSON response at "(.*?)" should include( keys)*:/)
            key = matches[1]

            if step.multiline_arg.respond_to? :rows
              step.multiline_arg.rows.each do |nested_key, value|
                add_json("#{key}/#{nested_key}", json_value(value))
              end
            else
              add_json(key, JSON.parse(step.multiline_arg))
            end
          elsif matches = step.name.match(/the JSON response at "(.*?)" should be ([^ ]*?)$/)
            keys = matches[1]
            value = matches[2]
            add_json(keys, json_value(value))
          elsif matches = step.name.match(/the JSON response at "(.*?)" should be (variable )*"(.*?)"/)
            keys = matches[1]
            value = matches[3]
            add_json(keys, value)
          end

          @prior_keyword = "Then"
        end
      end

      def tag_name(tag)
        @endpoint.group = Group.for_tag(tag)
      end

      private

      def log(message)
        @log ||= File.open("doc-debug.log", "w")
        @log << message + "\n"
      end

      def add_json(path, terminal_value)
        keys = path.split("/")

        return @example.json_response[path] = terminal_value if keys.size == 1

        keys.each_cons(2).reduce(@example.json_response) do |current, (key_one_string, key_two)|
          key_one = if key_one_string.match(/^\d+$/)
            key_one_string.to_i
          else
            key_one_string
          end

          value = case key_two
          when keys.last
            if current[key_one].is_a?(Hash)
              current[key_one].merge(key_two => terminal_value)
            else
              {key_two => terminal_value}
            end
          when /^\d+$/
            if current[key_one].is_a?(Array)
              current[key_one]
            else
              []
            end
          else
            current[key_one] || {}
          end

          current[key_one] = value

          value
        end
      end

      def json_value(string)
        JSON.parse('{"key":' + string + '}')["key"]
      end

      def write_html
        endpoints_by_group = @endpoints.group_by(&:group).sort_by { |group, _| group.name }

        html = Arbre::Context.new do
          head do
            link rel: "stylesheet", href: "https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css"
            link rel: "stylesheet", href: "https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap-theme.min.css"
            style do
              "
                .summary, .panel-heading {
                  cursor: pointer;
                }

                nav {
                  margin-top: 38px;
                  min-width: 255px;
                  top: 0;
                  bottom: 0;
                  padding-right: 12px;
                  padding-bottom: 12px;
                  overflow-y: auto;
                }
              ".html_safe
            end
            script src: "https://code.jquery.com/jquery-2.1.1.min.js"
            script src: "https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"
          end

          body do
            div class: "container padded" do
              div class: "col-md-3" do
                nav class: "hidden-sm hidden-xs affix nav" do
                  div class: "list-group" do
                    endpoints_by_group.each do |group, _|
                      a group.name, href: "##{group.key}", class: "list-group-item"
                    end
                  end
                end
              end

              div class: "col-md-9" do
                endpoints_by_group.each do |group, endpoints|
                  a name: group.key
                  h1 group.name

                  endpoints.sort_by(&:sort_order).each do |endpoint|
                    div class: "endpoint" do
                      div class: "summary well well-sm" do
                        text_node endpoint.name
                        span class: "glyphicon glyphicon-plus pull-right"
                      end

                      div class: "detail panel panel-default", style: "display:none" do
                        div class: "panel-heading" do
                          h2 do
                            text_node endpoint.name
                            span class: "glyphicon glyphicon-minus pull-right"
                          end
                        end

                        div class: "panel-body" do
                          div do
                            endpoint.description.split(/\n/).each do |line|
                              div line
                            end
                          end

                          h3 "Parameters"

                          table class: "table table-striped table-bordered" do
                            thead do
                              tr do
                                th { "Name" }
                                th { "Type" }
                              end
                            end

                            tbody do
                              endpoint.parameters.each do |parameter|
                                tr do
                                  td { parameter.type }
                                  td { parameter.name }
                                end
                              end
                            end
                          end

                          h3 "Examples"
                          endpoint.examples.each do |example|
                            panel_type = case example.code
                            when 200..299
                              "success"
                            when 400..499
                              "warning"
                            when 500.599
                              "error"
                            end

                            div class: "panel panel-#{panel_type}" do
                              div example.name, class: "panel-heading"

                              div class: "panel-body" do
                                h4 "Request parameters"
                                table class: "table table-striped table-bordered" do
                                  thead do
                                    tr do
                                      th { "Name" }
                                      th { "Type" }
                                      th { "Value" }
                                    end
                                  end

                                  tbody do
                                    example.parameters.each do |parameter|
                                      tr do
                                        td { parameter.type }
                                        td { parameter.name }
                                        td { parameter.value }
                                      end
                                    end
                                  end
                                end

                                h4 "Response"

                                div class: "panel panel-default" do
                                  div class: "panel-heading" do
                                    div "Code: #{example.code}"
                                    div "Content-Type: #{example.content_type}"
                                  end

                                  div class: "panel-body" do
                                    if example.json_response.empty?
                                      "Empty body"
                                    else
                                      json = JSON.pretty_generate(example.json_response)
                                      code json.gsub("\n", "<br>").gsub(" ", "&nbsp").html_safe
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end

            script "
              $(document).ready(function(){
                $('.summary').click(function() {
                  $(this).hide();
                  $(this).closest('.endpoint').find('.detail').show();
                });

                $('.detail .panel-heading').click(function() {
                  $(this).closest('.detail').hide();
                  $(this).closest('.endpoint').find('.summary').show();
                });
              });
            ".html_safe
          end
        end

        file = File.open("docs.html", "w")
        file << html.to_s
        file.close
      end
    end
  end
end
