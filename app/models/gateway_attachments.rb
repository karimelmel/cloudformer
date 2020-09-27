class Gateway_attachments < CF_converter
  
  attr_accessor :name
  @@gateway_attach_id = 1

  def self.post_selection(template)
    gateway_entries = []
    if template.selected_resources && template.selected_resources[:igws]
      template.selected_resources[:igws].each do |igw|
        if igw[:attachment_set]
          igw[:attachment_set].each do |attach|
            gw_attach = attach.clone
            gw_attach.merge!({:name=>"gw#{@@gateway_attach_id}", :gw_type=>"InternetGateway", :gateway_id=>igw[:internet_gateway_id]})
            gateway_entries << gw_attach
            @@gateway_attach_id = @@gateway_attach_id + 1
          end
        end
      end
    end
    if template.selected_resources && template.selected_resources[:vgws]
      template.selected_resources[:vgws].each do |vgw|
        if vgw[:attachments]
          vgw[:attachments].each do |attach|
            gw_attach = attach.clone
            gw_attach.merge!({:name=>"gw#{@@gateway_attach_id}", :gw_type=>"VpnGateway", :gateway_id=>vgw[:vpn_gateway_id]})
            gateway_entries << gw_attach
            @@gateway_attach_id = @@gateway_attach_id + 1
          end
        end
      end
    end
    template.selected_resources.merge!({:gateway_attachments => gateway_entries})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::VPCGatewayAttachment")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:vpc_id], template, name_mappings)}) if resource[:vpc_id] 
    if resource[:gw_type] == "InternetGateway"
      props.merge!({"InternetGatewayId" => ref_or_literal(:igws, resource[:gateway_id], template, name_mappings)}) if resource[:gateway_id] 
    elsif resource[:gw_type] == "VpnGateway"
      props.merge!({"VpnGatewayId" => ref_or_literal(:vgws, resource[:gateway_id], template, name_mappings)}) if resource[:gateway_id] 
    end

    return @cf_definition.deep_merge({ Gateway_attachments.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
