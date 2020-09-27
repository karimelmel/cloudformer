class Security_Group_Egresses < CF_converter

  attr_accessor :name
  @@egress_id = 1

  def self.post_selection(template)
    props = []
    if template.selected_resources && template.selected_resources[:security_groups]
      template.selected_resources[:security_groups].each do |group|
        if group[:ip_permissions_egress]
          group[:ip_permissions_egress].each do |rule|
            if !rule[:groups].empty?
              rule[:groups].each do |perm|
                gprop = {
                  :name            => "egress#{@@egress_id}",
                  :protocol        => rule[:ip_protocol],
                  :from_port       => rule[:from_port],
                  :to_port         => rule[:to_port],
                  :dest_group_id   => perm[:group_id]}

                if group[:vpc_id]
                  gprop.merge!({:group_id => group[:group_id]})
                else
                  gprop.merge!({:group_name => group[:group_name]})
                end

                props.push(gprop)
                @@egress_id = @@egress_id + 1
              end
            end
            if !rule[:ip_ranges].empty?
              rule[:ip_ranges].each do |perm|
                gprop = {
                  :name            => "egress#{@@egress_id}",
                  :protocol        => rule[:ip_protocol],
                  :from_port       => rule[:from_port],
                  :to_port         => rule[:to_port],
                  :cidr_ip         => perm[:cidr_ip]}

                if group[:vpc_id]
                  gprop.merge!({:group_id => group[:group_id]})
                else
                  gprop.merge!({:group_name => group[:group_name]})
                end

                props.push(gprop)
                @@egress_id = @@egress_id + 1
              end
            end
          end
        end
      end
    end
    template.selected_resources.merge!({:securitygroupegresses => props})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::SecurityGroupEgress")
  end

  def convert(resource, template, name_mappings)

    props = {}

    props.merge!({"GroupName" => ref_or_literal(:security_groups, resource[:group_name], template, name_mappings)}) if resource[:group_name]
    props.merge!({"GroupId" => ref_or_literal(:security_groups, resource[:group_id], template, name_mappings)}) if resource[:group_id]
    props.merge!({"IpProtocol" => resource[:protocol].to_s}) if resource[:protocol]
    props.merge!({"FromPort"   => resource[:from_port].to_s}) if resource[:from_port]
    props.merge!({"ToPort"     => resource[:to_port].to_s}) if resource[:to_port]
    props.merge!({"DestinationSecurityGroupId" => ref_or_literal(:security_groups, resource[:dest_group_id], template, name_mappings)}) if resource[:dest_group_id]
    props.merge!({"CidrIp"     => resource[:cidr_ip].to_s}) if resource[:cidr_ip]


    return @cf_definition.deep_merge({ Security_Group_Egresses.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end

end
