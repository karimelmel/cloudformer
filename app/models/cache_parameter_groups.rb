class Cache_Parameter_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the ElastiCache Cache parameter groups we care about
      cache = AWS::ElastiCache.new(:region => region)
      pgs = cache.client.describe_cache_parameter_groups().data[:cache_parameter_groups]
      all_pgs = []
      pgs.each do |pg|
        if !pg[:cache_parameter_group_name].starts_with?("default")
          full_pg = pg.clone
          full_params = cache.client.describe_cache_parameters(:cache_parameter_group_name => pg[:cache_parameter_group_name]).data[:parameters]
          clean_params = {}
          full_params.each do |param|
            clean_params.merge!({param[:parameter_name] => param[:parameter_value]}) if param[:parameter_value] != nil && param[:is_modifiable]
          end
          full_pg.merge!({:parameters => clean_params})
          all_pgs << full_pg
        end
      end
      all_resources.merge!({:cache_parameter_groups => all_pgs})
    rescue => e
      all_errors.merge!({:cache_parameter_groups => e.message})
      all_resources.merge!({:cache_parameter_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "cpg" + resource[:cache_parameter_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:description]}\n " +
           "Family: #{resource[:cache_parameter_group_family]}"
  end  
  
  def self.OutputList(resource)
    return {"Parameter Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Cache_Parameter_Groups.ResourceName(resource)
    super(@name, "AWS::ElastiCache::ParameterGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})
    props.merge!({"CacheParameterGroupFamily" => resource[:cache_parameter_group_family]})
    props.merge!({"Properties" => resource[:parameters]}) if resource[:parameters]
    return @cf_definition.deep_merge({ Cache_Parameter_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
