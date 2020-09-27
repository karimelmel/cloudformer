class Dhcps < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the dhcp options resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_resources.merge!({:dhcps => ec2.client.describe_dhcp_options().data[:dhcp_options_set]})
    rescue => e
      all_errors.merge!({:dhcps => e.message})
      all_resources.merge!({:dhcps => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:dhcp_options_id].tr('^A-Za-z0-9', '')
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
    configs = ""  
    sep = ""
    if resource[:dhcp_configuration_set]
      resource[:dhcp_configuration_set].each do |config|
        configs = configs + sep +  "#{config[:key]}: "
        sep1 = ""
        config[:value_set].each do |value|
          configs = configs + sep1 + value[:value]
          sep1 = ","
        end
        sep = "\n"
      end
    end          
    return "DHCPOptionsId: #{resource[:dhcp_options_id]} \n" +
           "DHCPConfig: #{configs}" +
           tags
  end

  def self.OutputList(resource)
    return {"DHCP Options" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Dhcps.ResourceName(resource)
    super(@name, "AWS::EC2::DHCPOptions")
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

    if resource[:dhcp_configuration_set]
      resource[:dhcp_configuration_set].each do |config|
        config_value = []
        config[:value_set].each do |value|
          config_value.push(value[:value].tr(' ', ''))
        end
        props.merge!("DomainName" => config_value[0]) if config[:key] == "domain-name"
        props.merge!("NetbiosNodeType" => config_value[0]) if config[:key] == "netbios-node-type"
        props.merge!("DomainNameServers" => config_value) if config[:key] == "domain-name-servers"
        props.merge!("NetbiosNameServers" => config_value) if config[:key] == "netbios-name-servers"
        props.merge!("NtpServers" => config_value) if config[:key] == "ntp-servers"
      end
    end          

    return @cf_definition.deep_merge({ Dhcps.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
