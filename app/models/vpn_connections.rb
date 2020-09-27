class Vpn_connections < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the VPN connection resources we care about
      ec2 = AWS::EC2.new(:region => region)
      vpn_conns = []
      ec2.client.describe_vpn_connections().data[:vpn_connection_set].each do |vpnc|
	vpnc_fixed = vpnc.clone
        vpnc_fixed.reject!{ |k| k == :vgw_telemetry }
        vpn_conns << vpnc_fixed
      end
      all_resources.merge!({:vpn_connections => vpn_conns})
    rescue => e
      all_errors.merge!({:vpn_connections => e.message})
      all_resources.merge!({:vpn_connections => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:vpn_connection_id].tr('^A-Za-z0-9', '')
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
    return "VPNConnectionId: #{resource[:vpn_connection_id]} \n" +
           "VPCType: #{resource[:vpn_type]} \n" +
           "CustomerGatewayId: #{resource[:customer_gateway_id]} \n" +
           tags
  end

  def self.OutputList(resource)
    return {"VPN Connection Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = Vpn_connections.ResourceName(resource)
    super(@name, "AWS::EC2::VPNConnection")
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

    props.merge!({"Type" => resource[:vpn_type]})
    props.merge!({"StaticRoutesOnly" => resource[:options][:static_routes_only] ? "true" : "false"}) if resource[:options] && resource[:options][:static_routes_only]
    props.merge!({"VpnGatewayId" => ref_or_literal(:vgws, resource[:vpn_gateway_id], template, name_mappings)}) if resource[:vpn_gateway_id] 
    props.merge!({"CustomerGatewayId" => ref_or_literal(:cgws, resource[:customer_gateway_id], template, name_mappings)}) if resource[:customer_gateway_id] 

    return @cf_definition.deep_merge({ Vpn_connections.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
