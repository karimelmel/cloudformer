class Dhcp_associations < CF_converter
  
  attr_accessor :name
  @@dhcp_assoc_id = 1

  def self.post_selection(template)
    dhcp_entries = []
    if template.selected_resources && template.selected_resources[:vpcs]
      template.selected_resources[:vpcs].each do |vpc|
        if vpc[:dhcp_options_id]
          dhcp_entries << {:name=>"dchpassoc#{@@dhcp_assoc_id}", :vpc_id=>vpc[:vpc_id], :dhcp_options_id=>vpc[:dhcp_options_id]}
          @@dhcp_assoc_id = @@dhcp_assoc_id + 1
        end
      end
    end
    template.selected_resources.merge!({:dhcp_associations => dhcp_entries})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::VPCDHCPOptionsAssociation")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:vpc_id], template, name_mappings)}) if resource[:vpc_id] 
    props.merge!({"DhcpOptionsId" => ref_or_literal(:dhcps, resource[:dhcp_options_id], template, name_mappings)}) if resource[:dhcp_options_id] 

    return @cf_definition.deep_merge({ Dhcp_associations.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
