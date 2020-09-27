class Network_acl_entries < CF_converter
  
  attr_accessor :name
  @@network_acl_id = 1

  def self.post_selection(template)
    network_acl_entries = []
    if template.selected_resources && template.selected_resources[:network_acls]
      template.selected_resources[:network_acls].each do |na|
        if na[:entry_set]
          na[:entry_set].each do |acl|
            if acl[:rule_number] && acl[:rule_number] < 32767
              acl_entry = acl.clone
              acl_entry.merge!({:name=>"acl#{@@network_acl_id}", :network_acl_id=>na[:network_acl_id]})
              network_acl_entries << acl_entry
              @@network_acl_id = @@network_acl_id + 1
            end
          end
        end
      end
    end
    template.selected_resources.merge!({:network_acl_entries => network_acl_entries})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::NetworkAclEntry")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"CidrBlock" => resource[:cidr_block]}) if resource[:cidr_block]
    props.merge!({"Egress" => resource[:egress].to_s()}) if resource[:egress]
    props.merge!({"Protocol" => resource[:protocol]}) if resource[:protocol]
    props.merge!({"RuleAction" => resource[:rule_action]}) if resource[:rule_action]
    props.merge!({"RuleNumber" => resource[:rule_number].to_s}) if resource[:rule_number]

    icmp = {}
    icmp_type_code = resource[:icmp_type_code]
    icmp.merge!({"Code" => icmp_type_code[:code].to_s}) if icmp_type_code && icmp_type_code[:code]
    icmp.merge!({"Type" => icmp_type_code[:type].to_s}) if icmp_type_code && icmp_type_code[:type]
    props.merge!({"Icmp" => icmp}) if !icmp.empty?

    ports = {}
    port_range = resource[:port_range]
    ports.merge!({"From" => port_range[:from].to_s}) if port_range && port_range[:from]
    ports.merge!({"To" => port_range[:to].to_s}) if port_range && port_range[:to]
    props.merge!({"PortRange" => ports}) if !ports.empty?

    props.merge!({"NetworkAclId" => ref_or_literal(:network_acls, resource[:network_acl_id], template, name_mappings)}) if resource[:network_acl_id] 

    return @cf_definition.deep_merge({ Network_acl_entries.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
