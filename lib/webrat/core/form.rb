require "webrat/core/field"
require "webrat/core_extensions/blank"

require "webrat/core/element"

module Webrat
  class Form < Element #:nodoc:
    attr_reader :element
    
    def self.xpath_search
      ".//form"
    end
    
    def initialize(*args)
      super
      
      fields # preload
      labels # preload
    end
    
    def find_select_option(option_text)
      select_fields = fields_by_type([SelectField])

      select_fields.each do |select_field|
        result = select_field.find_option(option_text)
        return result if result
      end

      nil
    end

    def fields
      @fields ||= Webrat::XML.xpath_search(@element, *Field.xpath_search).map do |element|
        @session.element_to_webrat_element(element)
      end
    end
    
    def labels
      @labels ||= Webrat::XML.css_search(element, "label").map do |element|
        @session.element_to_webrat_element(element)
      end
    end
    
    def submit
      @session.request_page(form_action, form_method, params)
    end
    
    def field_named(name, *field_types)
      possible_fields = fields_by_type(field_types)
      possible_fields.detect { |possible_field| possible_field.matches_name?(name) }
    end
    
    def matches_id?(id)
      Webrat::XML.attribute(@element, "id") == id.to_s
    end
    
  protected
  
    def fields_by_type(field_types)
      if field_types.any?
        fields.select { |f| field_types.include?(f.class) }
      else
        fields
      end
    end
    
    def params
      all_params = {}
      
      fields.each do |field|
        next if field.to_param.nil?
        merge(all_params, field.to_param)
      end
      
      all_params
    end
    
    def form_method
      Webrat::XML.attribute(@element, "method").blank? ? :get : Webrat::XML.attribute(@element, "method").downcase
    end
    
    def form_action
      Webrat::XML.attribute(@element, "action").blank? ? @session.current_url : Webrat::XML.attribute(@element, "action")
    end
    
    def merge(all_params, new_param)
      new_param.each do |key, value|
        case all_params[key]
        when *hash_classes
          merge_hash_values(all_params[key], value)
        when Array
          all_params[key] += value
        else
          all_params[key] = value
        end
      end
    end
  
    def merge_hash_values(a, b) # :nodoc:
      a.keys.each do |k|
        if b.has_key?(k)
          case [a[k], b[k]].map{|value| value.class}
          when *hash_classes.zip(hash_classes)
            a[k] = merge_hash_values(a[k], b[k])
            b.delete(k)
          when [Array, Array]
            a[k] += b[k]
            b.delete(k)
          end
        end
      end
      a.merge!(b)
    end
    
    def hash_classes
      klasses = [Hash]
      
      case Webrat.configuration.mode
      when :rails
        klasses << HashWithIndifferentAccess
      when :merb
        klasses << Mash
      end
      
      klasses
    end
    
  end
end
