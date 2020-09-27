class Cache_Security_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the ElastiCache Cache security groups we care about
      elasticache = AWS::ElastiCache.new(:region => region)
      all_resources.merge!({:cache_security_groups => elasticache.client.describe_cache_security_groups().data[:cache_security_groups]})
    rescue => e
      all_errors.merge!({:cache_security_groups => e.message})
      all_resources.merge!({:cache_security_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "csg" + resource[:cache_security_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:description]}"
  end  
  
  def self.OutputList(resource)
    return {"Security Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Cache_Security_Groups.ResourceName(resource)
    super(@name, "AWS::ElastiCache::SecurityGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})
    return @cf_definition.deep_merge({ Cache_Security_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
