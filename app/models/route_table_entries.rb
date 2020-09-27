class Route_table_entries < CF_converter
  
  attr_accessor :name
  @@route_entry_id = 1

  def self.post_selection(template)
    route_table_entries = []
    if template.selected_resources && template.selected_resources[:route_tables]
      template.selected_resources[:route_tables].each do |rt|
        if rt[:route_set]
          rt[:route_set].each do |route|
            if route[:gateway_id] != "local"
              route_entry = route.clone
              route_entry.merge!({:name=>"route#{@@route_entry_id}", :route_table_id=>rt[:route_table_id]});
              # If this is a route to a gateway, the gateway has to be associated with the VPC prior to the route being setup
              if route[:gateway_id]
                template.selected_resources[:gateway_attachments].each do |gw|
                  route_entry.merge!({:depends_on => gw[:name]}) if gw[:gateway_id] == route[:gateway_id]
                end
              end
              route_table_entries << route_entry
              @@route_entry_id = @@route_entry_id + 1
            end
          end
        end
      end
    end
    template.selected_resources.merge!({:route_table_entries => route_table_entries})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::Route")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"VpcPeeringConnectionId" => resource[:vpc_peering_connection_id]}) if resource[:vpc_peering_connection_id]
    props.merge!({"DestinationCidrBlock" => resource[:destination_cidr_block]}) if resource[:destination_cidr_block]
    props.merge!({"RouteTableId" => ref_or_literal(:route_tables, resource[:route_table_id], template, name_mappings)}) if resource[:route_table_id]

    # If NetworkInterfaceId is a ref, use it instead of Instance
    eni = ""
    eni = ref_or_literal(:enis, resource[:network_interface_id], template, name_mappings) if resource[:network_interface_id]
    if eni.class == String
      props.merge!({"InstanceId" => ref_or_literal(:instances, resource[:instance_id], template, name_mappings)}) if resource[:instance_id] 
    end

    # Only put NetworkInterfaceId on if InstanceId does not exist
    props.merge!({"NetworkInterfaceId" => eni}) if resource[:network_interface_id] && !props["InstanceId"]

    if resource[:gateway_id]
      gwid = ref_or_literal(:cgws, resource[:gateway_id], template, name_mappings)
      gwid = ref_or_literal(:igws, resource[:gateway_id], template, name_mappings) if gwid == resource[:gateway_id]
      gwid = ref_or_literal(:vgws, resource[:gateway_id], template, name_mappings) if gwid == resource[:gateway_id]
      props.merge!({"GatewayId" => gwid})
    end

    ret = { "Type" => @cf_type, "Properties" => props }
    ret.merge!({"DependsOn" => resource[:depends_on]}) if resource[:depends_on]

    return @cf_definition.deep_merge({ Route_table_entries.map_resource_name(@name, name_mappings) => ret })
  end
    
end
