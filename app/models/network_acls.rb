class Network_acls < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the network ACL resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:network_acls => ec2.client.describe_network_acls().data[:network_acl_set]})
    rescue => e
      all_errors.merge!({:network_acls => e.message})
      all_resources.merge!({:network_acls => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:network_acl_id].tr('^A-Za-z0-9', '')
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
    return "VpcId: #{resource[:vpc_id]} " +
           tags
  end

  def self.OutputList(resource)
    return {"Network ACL Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Network_acls.ResourceName(resource)
    super(@name, "AWS::EC2::NetworkAcl")
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

    return @cf_definition.deep_merge({ Network_acls.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
