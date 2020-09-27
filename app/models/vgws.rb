class Vgws < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the VPN gateway resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:vgws => ec2.client.describe_vpn_gateways().data[:vpn_gateway_set]})
    rescue => e
      all_errors.merge!({:vgws => e.message})
      all_resources.merge!({:vgws => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:vpn_gateway_id].tr('^A-Za-z0-9', '')
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
    if resource[:attachments]
      resource[:attachments].each do |attachment|
        attachments = attachments + "#{attachment[:vpc_id]} " if attachment[:vpc_id] != nil
      end
    end          
    return "VPNGatewayId: #{resource[:vpn_gateway_id]} \n" +
           "Type : " + resource[:vpn_type] + "\n" +
           "Attached to: " + attachments +
           tags
  end

  def self.OutputList(resource)
    return {"VPN Gateway Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Vgws.ResourceName(resource)
    super(@name, "AWS::EC2::VPNGateway")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Type" => resource[:vpn_type]}) if resource[:vpn_type]
    
    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    return @cf_definition.deep_merge({ Vgws.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
