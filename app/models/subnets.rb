class Subnets < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the subnet resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:subnets => ec2.client.describe_subnets().data[:subnet_set]})
    rescue => e
      all_errors.merge!({:subnets => e.message})
      all_resources.merge!({:subnets => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:subnet_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" "#{tag[:key]}: #{tag[:value]} " if tag[:value] != nil
      end
    end          
    return "VpcId: #{resource[:vpc_id]} \n" +
           "AvailabiltyZone: #{resource[:availability_zone]} \n" +
           "CidrBlock: #{resource[:cidr_block]} " +
           tags
  end

  def self.OutputList(resource)
    return {"Subnet Id" => "Id,Ref",
            "Availability Zone" => "AvailabilityZone,GetAtt,AvailabilityZone"}
  end

  def initialize(resource)
    @name = Subnets.ResourceName(resource)
    super(@name, "AWS::EC2::Subnet")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"CidrBlock" => resource[:cidr_block]}) if resource[:cidr_block]
    props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone]
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

    return @cf_definition.deep_merge({ Subnets.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
