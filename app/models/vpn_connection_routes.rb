class Vpn_connection_routes < CF_converter

  attr_accessor :name
  @@route_id = 1
  
  def self.post_selection(template)
    vpn_conn_routes = []
    if template.selected_resources && template.selected_resources[:vpn_connections]
      template.selected_resources[:vpn_connections].each do |vpnc|
        vpnc[:routes].each do |route|
          vpn_conn_routes.push({
            :name                   => "croute#{@@route_id}",
            :vpn_connection_id      => vpnc[:vpn_connection_id],
            :destination_cidr_block => route[:destination_cidr_block]
            }) if vpnc[:vpn_connection_id] && route[:destination_cidr_block]
          @@route_id = @@route_id + 1
        end if vpnc[:routes]
      end
    end
    template.selected_resources.merge!({:vpn_connection_routes => vpn_conn_routes})
  end
  
  def self.ResourceName(resource)
    return resource[:name]
  end
  
  def initialize(resource)
    @name = Vpn_connection_routes.ResourceName(resource)
    super(@name, "AWS::EC2::VPNConnectionRoute")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"VpnConnectionId" => ref_or_literal(:vpn_connections, resource[:vpn_connection_id], template, name_mappings)}) if resource[:vpn_connection_id] 
    props.merge!({"DestinationCidrBlock" => resource[:destination_cidr_block]}) if resource[:destination_cidr_block] 

    return @cf_definition.deep_merge({ Vpn_connections.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
