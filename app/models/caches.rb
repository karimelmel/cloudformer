class Caches < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the ElastiCache cache clusters we care about
      ecache = AWS::ElastiCache.new(:region => region)
      ccs = []
      ecache.client.describe_cache_clusters().data[:cache_clusters].each do |cache|
        full_cache = cache.clone
        full_cache[:preferred_availability_zones] = [ "#{region}a", "#{region}b" ]
        full_cache.reject!{ |k| k == :cache_cluster_create_time }
        full_cache.reject!{ |k| k == :cache_nodes }
        full_cache.merge!({:port => cache[:cache_nodes].first[:port]}) if cache[:cache_nodes] && !cache[:cache_nodes].empty?
        ccs << full_cache
      end
      all_resources.merge!({:caches => ccs})
    rescue => e
      all_errors.merge!({:caches => e.message})
      all_resources.merge!({:caches => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "cache" + resource[:cache_cluster_id].tr('^A-Za-z0-9', '')
  end
    
  def self.get_dependencies(resource, all_resources)
    csgResources = []
    if resource[:cache_security_groups]
      resource[:cache_security_groups].each do |sg|
        all_resources[:cache_security_groups].each do |all_sg|
          csgResources.push(all_sg) if all_sg[:cache_security_group_name].eql?(sg[:cache_security_group_name])
        end
      end
    end
    sgResources = []
    if resource[:security_groups]
      resource[:security_groups].each do |sg|
        all_resources[:security_groups].each do |all_sg|
          sgResources.push(all_sg) if all_sg[:fake_id].eql?(sg[:security_group_id])
        end
      end
    end
    subnetGroups = []
    if resource[:cache_subnet_group_name]
      all_resources[:cache_subnet_groups].each do |all_sg|
        subnetGroups.push(all_sg) if all_sg[:cache_subnet_group_name].eql?(resource[:cache_subnet_group_name])
      end
    end
    pgResources = []
    if resource[:cache_parameter_group] && resource[:cache_parameter_group][:cache_parameter_group_name]
      all_resources[:cache_parameter_groups].each do |all_pg|
        pgResources.push(all_pg) if all_pg[:cache_parameter_group_name] == resource[:cache_parameter_group][:cache_parameter_group_name]
      end
    end
    return { :cache_security_groups => csgResources, :security_groups => sgResources, :cache_subnet_groups => subnetGroups, :cache_parameter_groups => pgResources }
  end

  def self.get_resource_attributes(resource)
    return "Node Type: #{resource[:cache_node_type]} \n" +
           "Engine: #{resource[:engine]} \n" +
           "Engine Version: #{resource[:engine_version]} \n" +
           "Availability Zone: #{resource[:preferred_availability_zone]}" 
  end

  def self.OutputList(resource)
    return {"Cache Name" => "Name,Ref",
            "Configuration Endpoint Address" => "Address,GetAtt,ConfigurationEndpoint.Address",
            "Configuration Endpoint Port" => "Port,GetAtt,ConfigurationEndpoint.Port"}
  end


  def initialize(resource)
    @name = Caches.ResourceName(resource)
    super(@name, "AWS::ElastiCache::CacheCluster")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AutoMinorVersionUpgrade" => resource[:auto_minor_version_upgrade].to_s}) if resource[:auto_minor_version_upgrade]
    props.merge!({"AZMode" => resource[:preferred_availability_zone] == "Multiple" ? "cross-az" : "single-az"}) if resource[:preferred_availability_zone]
    props.merge!({"CacheNodeType" => resource[:cache_node_type]}) if resource[:cache_node_type]
    props.merge!({"Engine" => resource[:engine].to_s}) if resource[:engine]
    props.merge!({"EngineVersion" => resource[:engine_version].to_s}) if resource[:engine_version]
    props.merge!({"NumCacheNodes" => resource[:num_cache_nodes].to_s}) if resource[:num_cache_nodes]
    props.merge!({"Port" => resource[:port].to_s}) if resource[:port]
    if resource[:preferred_availability_zone] && resource[:preferred_availability_zone] == "Multiple"
      props.merge!({"PreferredAvailabilityZones" => [resource[:preferred_availability_zones]]})
    else
      props.merge!({"PreferredAvailabilityZone" => resource[:preferred_availability_zone]})
    end
    props.merge!({"PreferredMaintenanceWindow" => resource[:preferred_maintenance_window].to_s}) if resource[:preferred_maintenance_window]

    props.merge!({"NotificationTopicArn" => ref_or_literal(:topics, resource[:notification_configuration][:topic_arn], template, name_mappings)}) if resource[:notification_configuration] && resource[:notification_configuration][:topic_arn]

    props.merge!({"CacheParameterGroupName" => ref_or_literal(:cache_parameter_groups, resource[:cache_parameter_group][:cache_parameter_group_name], template, name_mappings)}) if resource[:cache_parameter_group] && resource[:cache_parameter_group][:cache_parameter_group_name] && !resource[:cache_parameter_group][:cache_parameter_group_name].starts_with?("default")

    # If this is in a VPC populate the subnet group and the VPC security groups
    # Otherwise populate the cache security groups
    if resource[:cache_subnet_group_name]
      props.merge!({"CacheSubnetGroupName" => ref_or_literal(:cache_subnet_groups, resource[:cache_subnet_group_name],template, name_mappings)})
      if resource[:security_groups]
        groups = []
        resource[:security_groups].each do |group|
          groups.push(ref_or_getatt(:security_groups, group[:security_group_id], :fake_id, "GroupId", template, name_mappings))        
        end
        props.merge!({"VpcSecurityGroupIds" => groups}) if !groups.empty?
      end
    else
      if resource[:cache_security_groups]
        groups = []
        resource[:cache_security_groups].each do |group|
          groups.push(ref_or_literal(:cache_security_groups, group[:cache_security_group_name], template, name_mappings))        
        end
        props.merge!({"CacheSecurityGroupNames" => groups}) if !groups.empty?
      end
    end

    return @cf_definition.deep_merge({ Caches.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
