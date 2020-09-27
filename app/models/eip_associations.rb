class EIP_Associations < CF_converter
  
  attr_accessor :name
  @@association_id = 1

  def self.post_selection(template)
    props = []
    # Check for all ENIs attached to instances
    if template.selected_resources && template.selected_resources[:instances]
      template.selected_resources[:instances].each do |instance|
        if instance[:vpc_id]
          instance[:network_interface_set].each do |ni|
            ni[:private_ip_addresses_set].each do |ip|
              if ip[:association] && ip[:association][:public_ip]
                template.all_resources[:eips].each do |eip|
                  if eip[:domain].eql?("vpc") && eip[:public_ip].eql?(ip[:association][:public_ip])
                    eip_properties = {:name=>"assoc#{@@association_id}", :public_ip => eip[:public_ip], :allocation_id => eip[:allocation_id]}
                    if !ip[:primary]
                      eip_properties[:private_ip_address] = ip[:private_ip_address]
                    end
                    # If this is device 0 reference the instance otherwise reference the network interface
                    if  ni[:attachment] && ni[:attachment][:device_index] != 0
                      eip_properties[:network_interface_id] = ni[:network_interface_id]
                    else
                      eip_properties[:instance_id] = instance[:instance_id]
                    end
                    props << eip_properties
                    @@association_id = @@association_id + 1
                  end
                end
              end
            end if ni[:private_ip_addresses_set]
          end if instance[:network_interface_set]
        end
      end
    end
    # Check for unattached network interfaces
    if template.selected_resources && template.selected_resources[:enis]
      template.selected_resources[:enis].each do |eni|
        if !eni[:attachment]
          eni[:private_ip_addresses_set].each do |ip|
            if ip[:association] && ip[:association][:public_ip]
              template.all_resources[:eips].each do |eip|
                if eip[:domain].eql?("vpc") && eip[:public_ip].eql?(ip[:association][:public_ip])
                  eip_properties = {:name=>"assoc#{@@association_id}", :public_ip => eip[:public_ip], :allocation_id => eip[:allocation_id], :network_interface_id => eni[:network_interface_id]}
                  if !ip[:primary]
                    eip_properties[:private_ip_address] = ip[:private_ip_address]
                  end
                  props << eip_properties
                  @@association_id = @@association_id + 1
                end
              end
            end
          end if eni[:private_ip_addresses_set]
        end
      end
    end
    template.selected_resources.merge!({:eipassociations => props})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::EIPAssociation")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AllocationId" => ref_or_getatt(:eips, resource[:public_ip], :public_ip, "AllocationId",  template, name_mappings)}) if resource[:allocation_id]
    props.merge!({"PrivateIpAddress" => resource[:private_ip_address]}) if resource[:private_ip_address]
    props.merge!({"NetworkInterfaceId" => ref_or_literal(:enis, resource[:network_interface_id], template, name_mappings)}) if resource[:network_interface_id]
    props.merge!({"InstanceId" => ref_or_literal(:instances, resource[:instance_id], template, name_mappings)}) if resource[:instance_id] 
    return @cf_definition.deep_merge({ EIP_Associations.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
