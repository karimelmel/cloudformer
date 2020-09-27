class Igws < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the internet gateway resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:igws => ec2.client.describe_internet_gateways().data[:internet_gateway_set]})
    rescue => e
      all_errors.merge!({:igws => e.message})
      all_resources.merge!({:igws => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:internet_gateway_id].tr('^A-Za-z0-9', '')
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
    attachments = ""
    if resource[:attachment_set]
      resource[:attachment_set].each do |attachment|
        attachments = attachments + "#{attachment[:vpc_id]} " if attachment[:vpc_id] != nil
      end
    end          
    return "InternetGatewayId: #{resource[:internet_gateway_id]} \n" +
           "Attached to: " + attachments +
           tags
  end

  def self.OutputList(resource)
    return {"Internet Gateway Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Igws.ResourceName(resource)
    super(@name, "AWS::EC2::InternetGateway")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    return @cf_definition.deep_merge({ Igws.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
