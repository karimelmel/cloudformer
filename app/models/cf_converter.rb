class CF_converter
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end

  def self.post_load(template, region)
  end

  def self.post_selection(template)
  end

  def self.ResourceName(resource)
    return "uninitialized_name"
  end

  def self.OutputList(resource)
    return {}
  end
  
  def self.map_resource_name(name, name_mappings)
    retName = name
    retName = name_mappings[name] if name_mappings.has_key?(name)
    return retName
  end

  def self.get_resource_attributes(resource)
    return "There are no addtional attributes for this resource"
  end

  def self.get_resource_tooltip(template, resource_type, resource)
    return Object::const_get(template.resource_metadata[resource_type][:template_converter]).get_resource_attributes(resource)
  end

  @cf_definition = {}
  @cf_type = "AWS::CloudFormation::UnknownType"
  
  def initialize(resource_name, resource_type)
    @cf_definition = {}
    @cf_type = resource_type
  end

  def convert(resource, template, name_mappings)
    return @cf_definition
  end
  
  def ref_or_literal(resource_type, resource_name, template, name_mappings)
    retName = resource_name 
    if template.selected_resources[resource_type]
      template.selected_resources[resource_type].each do |resource|
        if resource[template.resource_metadata[resource_type][:resource_id]]
          if resource[template.resource_metadata[resource_type][:resource_id]].casecmp(resource_name) == 0 
            retName = { "Ref" => CF_converter.map_resource_name(Object::const_get(template.resource_metadata[resource_type][:template_converter]).ResourceName(resource), name_mappings)}
          end          
        end
      end
    end
    return retName
  end

  def ref_or_getatt(resource_type, resource_name, real_property_name, cf_property_name, template, name_mappings)
    retName = resource_name 
    if template.selected_resources[resource_type]
      template.selected_resources[resource_type].each do |resource|
        if resource[real_property_name]
          if resource[real_property_name].casecmp(resource_name) == 0
            retName = { "Fn::GetAtt" => [CF_converter.map_resource_name(Object::const_get(template.resource_metadata[resource_type][:template_converter]).ResourceName(resource), name_mappings), cf_property_name]}
          end          
        end
      end
    end
    return retName
  end

end
