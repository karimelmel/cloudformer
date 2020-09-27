class Cache_Security_Group_Ingresses < CF_converter
  
  attr_accessor :name
  @@ingress_id = 1

  def self.post_selection(template)
    props = []
    if template.selected_resources && template.selected_resources[:cache_security_groups]
      template.selected_resources[:cache_security_groups].each do |group|
        if group[:ec2_security_groups]
          group[:ec2_security_groups].each do |ec2grp|
            props << { :name=>"cingress#{@@ingress_id}",
                       :group_name => group[:cache_security_group_name],
                       :ec2_security_group_name => ec2grp[:ec2_security_group_name],
                       :ec2_security_group_owner_id => ec2grp[:ec2_security_group_owner_id]}
            @@ingress_id += 1
          end
        end
      end
    end
    template.selected_resources.merge!({:cachesecuritygroupingresses => props})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::ElastiCache::SecurityGroupIngress")
  end
  
  def convert(resource, template, name_mappings)

    props = {}

    props.merge!({"CacheSecurityGroupName" => ref_or_literal(:cache_security_groups, resource[:group_name], template, name_mappings)}) if resource[:group_name]
    props.merge!({"EC2SecurityGroupName" => ref_or_literal(:security_groups, resource[:ec2_security_group_name], template, name_mappings)}) if resource[:ec2_security_group_name]
    props.merge!({"EC2SecurityGroupOwnerId" => resource[:ec2_security_group_owner_id].to_s}) if resource[:ec2_security_group_owner_id] 

    return @cf_definition.deep_merge({ Cache_Security_Group_Ingresses.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
