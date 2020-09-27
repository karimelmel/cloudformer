class Cache_Subnet_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RDS DB subnet groups we care about
      ecache = AWS::ElastiCache.new(:region => region)
      sgs = ecache.client.describe_cache_subnet_groups().data[:cache_subnet_groups]
      all_resources.merge!({:cache_subnet_groups => sgs})
    rescue => e
      all_errors.merge!({:cache_subnet_groups => e.message})
      all_resources.merge!({:cache_subnet_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "cachesubnet" + resource[:cache_subnet_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets << subnet[:subnet_identifier]
      end
    end
    return "Description: #{resource[:cache_subnet_group_description]}\n " +
           "Subnets: #{subnets.to_s}"
  end  
  
  def self.OutputList(resource)
    return {"Subnet Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Cache_Subnet_Groups.ResourceName(resource)
    super(@name, "AWS::ElastiCache::SubnetGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:cache_subnet_group_description]})

    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets << ref_or_literal(:subnets, subnet[:subnet_identifier], template, name_mappings)
      end
    end
    props.merge!({"SubnetIds" => subnets}) if !subnets.empty?

    return @cf_definition.deep_merge({ Cache_Subnet_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
