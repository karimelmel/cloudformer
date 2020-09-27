class Security_Group_Ingresses < CF_converter
  
  attr_accessor :name
  @@ingress_id = 1

  def self.post_selection(template)
    props = []
    if template.selected_resources && template.selected_resources[:security_groups]
      template.selected_resources[:security_groups].each do |group|
        if group[:ip_permissions]
          group[:ip_permissions].each do |rule|
            if !rule[:groups].empty?
              rule[:groups].each do |perm|
                gprop = {
                  :name            => "ingress#{@@ingress_id}",
                  :protocol        => rule[:ip_protocol],
                  :from_port       => rule[:from_port],
                  :to_port         => rule[:to_port],
                  :source_group    => perm[:group_name],
                  :source_group_id => perm[:group_id],
                  :source_owner    => perm[:user_id]}

                if group[:vpc_id]
                  gprop.merge!({:group_id => group[:group_id]})
                else
                  gprop.merge!({:group_name => group[:group_name]})
                end

                props.push(gprop)
                @@ingress_id = @@ingress_id + 1
              end
            end
            if !rule[:ip_ranges].empty?
              rule[:ip_ranges].each do |perm|
                gprop = {
                  :name            => "ingress#{@@ingress_id}",
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
                @@ingress_id = @@ingress_id + 1
              end
            end
          end
        end
      end
    end
    template.selected_resources.merge!({:securitygroupingresses => props})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::SecurityGroupIngress")
  end
  
  def convert(resource, template, name_mappings)

    props = {}

    props.merge!({"GroupName" => ref_or_literal(:security_groups, resource[:group_name], template, name_mappings)}) if resource[:group_name]
    props.merge!({"GroupId" => ref_or_literal(:security_groups, resource[:group_id], template, name_mappings)}) if resource[:group_id]
    props.merge!({"IpProtocol" => resource[:protocol].to_s}) if resource[:protocol]
    props.merge!({"FromPort"   => resource[:from_port].to_s}) if resource[:from_port]
    props.merge!({"ToPort"     => resource[:to_port].to_s}) if resource[:to_port]
    props.merge!({"SourceSecurityGroupName" => ref_or_literal(:security_groups, resource[:source_group], template, name_mappings)}) if resource[:source_group]
    props.merge!({"SourceSecurityGroupId" => ref_or_literal(:security_groups, resource[:source_group_id], template, name_mappings)}) if resource[:source_group_id] && !resource[:source_group]
    props.merge!({"SourceSecurityGroupOwnerId" => resource[:source_owner].to_s}) if resource[:source_owner] 
    props.merge!({"CidrIp" => resource[:cidr_ip].to_s}) if resource[:cidr_ip]

    return @cf_definition.deep_merge({ Security_Group_Ingresses.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
