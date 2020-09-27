class Eips < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EIP resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:eips => ec2.client.describe_addresses().data[:addresses_set]})
    rescue => e
      all_errors.merge!({:eips => e.message})
      all_resources.merge!({:eips => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "eip" + resource[:public_ip].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    retResources = []
    if all_resources[:instances]
      all_resources[:instances].each do |instance|
        retResources.push(instance) if instance[:instance_id] == resource[:instance_id]
      end      
    end
    return { :instances => retResources }
  end
  
  def self.get_resource_attributes(resource)
    return "Domain: #{resource[:domain]}"
  end

  def self.OutputList(resource)
    return {"IP Address" => "IP,Ref"}
  end

  def initialize(resource)
    @name = Eips.ResourceName(resource)
    super(@name, "AWS::EC2::EIP")
  end
  
  def convert(resource, template, name_mappings)
    dependson = []
    props = {}
    if resource[:domain].eql?("vpc")
      props.merge!({"Domain" => resource[:domain]})
      # If this is attached to an instance in a subnet created in the template, an internet gateway must also be attached first
      if resource[:instance_id]
        separator = ""
        template.selected_resources[:gateway_attachments].each do |gw|
          dependson.push(gw[:name])
          separator = ","
        end
      end
      # for vpc-based EIPs we'll always create an attachment to the right network interface and IP
    else
      props.merge!({"InstanceId" => ref_or_literal(:instances, resource[:instance_id], template, name_mappings)}) if resource[:instance_id]
    end
    if !dependson.empty?
      return @cf_definition.deep_merge({ Eips.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "DependsOn" => dependson, "Properties" => props }})
    end
    return @cf_definition.deep_merge({ Eips.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
