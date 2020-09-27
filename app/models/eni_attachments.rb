class ENI_Attachments < CF_converter
  
  attr_accessor :name
  @@attachment_id = 1

  def self.post_selection(template)
    props = []
    if template.selected_resources && template.selected_resources[:instances]
      template.selected_resources[:instances].each do |instance|
        if instance[:vpc_id]
          instance[:network_interface_set].each do |ni|
            # Only support attachements for non-0 indexes right now until we support the full ENI/EIP config
            if  ni[:attachment] && ni[:attachment][:device_index] != 0
              full_props = {:name => "eniattach#{@@attachment_id}", :delete_on_termination => ni[:attachment][:delete_on_termination], :device_index => ni[:attachment][:device_index], :instance_id => instance[:instance_id], :network_interface_id => ni[:network_interface_id]}
              # To avoid issues with attaching EIPs to the primary (index 0) ENI on an instance, we need to
              # wait until all the EIP associations for the primary ENI are done before we attach this ENI to the instance
              depends = []
              if template.selected_resources[:eipassociations]
                template.selected_resources[:eipassociations].each do |assoc|
                  if assoc[:instance_id] && assoc[:instance_id].eql?(instance[:instance_id])
                    depends << assoc[:name]
                  end
                end
                full_props[:depends_on] = depends if !depends.empty?
              end

              props << full_props
              @@attachment_id = @@attachment_id + 1
            end
          end if instance[:network_interface_set]
        end
      end
    end
    template.selected_resources.merge!({:eniattachments => props})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::NetworkInterfaceAttachment")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DeleteOnTermination" => resource[:delete_on_termination].to_s()}) if resource[:delete_on_termination]
    props.merge!({"DeviceIndex" => resource[:device_index].to_s()}) if resource[:device_index]
    props.merge!({"NetworkInterfaceId" => ref_or_literal(:enis, resource[:network_interface_id], template, name_mappings)}) if resource[:network_interface_id] 
    props.merge!({"InstanceId" => ref_or_literal(:instances, resource[:instance_id], template, name_mappings)}) if resource[:instance_id] 
    resource_definition = { "Type" => @cf_type, "Properties" => props }
    resource_definition["DependsOn"] = resource[:depends_on] if resource[:depends_on]
    return @cf_definition.deep_merge({ ENI_Attachments.map_resource_name(@name, name_mappings) => resource_definition })
  end
    
end
