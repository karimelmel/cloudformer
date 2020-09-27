class Route_tables < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Route Table resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:route_tables => ec2.client.describe_route_tables().data[:route_table_set]})
    rescue => e
      all_errors.merge!({:route_tables => e.message})
      all_resources.merge!({:route_tables => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:route_table_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" + "#{tag[:key]}: #{tag[:value]} " if tag[:value] != nil
      end
    end          
    routes = ""
    if resource[:route_set]
      resource[:route_set].each do |route|
        src = ""
        src = route[:destination_cidr_block] if route[:destination_cidr_block]
        dest = ""
        dest = route[:gateway_id] if route[:gateway_id] 
        dest = route[:instance_id] if route[:instance_id]
        dest = route[:network_interface_id] if route[:network_interfact_id]
        dest = route[:gateway_id] if route[:gateway_id]
        routes = routes + "\n" + "Route: " + src + " => " + dest if src != "" && dest != ""
      end
    end
    associations = ""
    if resource[:association_set]
      resource[:association_set].each do |association|
        associations = associations + "#{association[:subnet_id]} " if association[:subnet_id] != nil
      end
    end          
    return "VpcId: #{resource[:vpc_id]} \n" + 
           "Subnets: #{associations} " + routes + tags
  end

  def self.OutputList(resource)
    return {"Route Table Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Route_tables.ResourceName(resource)
    super(@name, "AWS::EC2::RouteTable")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:vpc_id], template, name_mappings)}) if resource[:vpc_id]
    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    return @cf_definition.deep_merge({ Route_tables.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
