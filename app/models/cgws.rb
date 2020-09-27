class Cgws < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the customer gateway resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:cgws => ec2.client.describe_customer_gateways().data[:customer_gateway_set]})
    rescue => e
      all_errors.merge!({:cgws => e.message})
      all_resources.merge!({:cgws => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:customer_gateway_id].tr('^A-Za-z0-9', '')
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
    return "CustomerGatewayId: #{resource[:customer_gateway_id]} \n" +
           "Type: #{resource[:vpn_type]} \n" +
           "IPAddress: #{resource[:ip_address]} \n" +
           "BgpAsn: #{resource[:bgp_asn]} " +
           tags
  end

  def self.OutputList(resource)
    return {"Customer Gateway Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Cgws.ResourceName(resource)
    super(@name, "AWS::EC2::CustomerGateway")
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
    
    props.merge!({"Type" => resource[:vpn_type]}) if resource[:vpn_type]
    props.merge!({"IpAddress" => resource[:ip_address]}) if resource[:ip_address]
    props.merge!({"BgpAsn" => resource[:bgp_asn]}) if resource[:bgp_asn]

    return @cf_definition.deep_merge({ Cgws.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
