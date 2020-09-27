class Subnet_acl_associations < CF_converter
  
  attr_accessor :name
  @@subnet_assoc_id = 1

  def self.post_selection(template)
    subnet_acl_entries = []
    if template.selected_resources && template.selected_resources[:network_acls]
      template.selected_resources[:network_acls].each do |na|
        if na[:association_set]
          na[:association_set].each do |assoc|
            assoc_entry = assoc.clone
            assoc_entry.merge!({:name=>"subnetacl#{@@subnet_assoc_id}"})
            subnet_acl_entries << assoc_entry
            @@subnet_assoc_id = @@subnet_assoc_id + 1
          end
        end
      end
    end
    template.selected_resources.merge!({:subnet_acl_associations => subnet_acl_entries})
  end

  def self.OutputList(resource)
    return {"Association Id" => "AssociationId,GetAtt,AssociationId"}
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::SubnetNetworkAclAssociation")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"NetworkAclId" => ref_or_literal(:network_acls, resource[:network_acl_id], template, name_mappings)}) if resource[:network_acl_id] 
    props.merge!({"SubnetId" => ref_or_literal(:subnets, resource[:subnet_id], template, name_mappings)}) if resource[:subnet_id] 

    return @cf_definition.deep_merge({ Subnet_acl_associations.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
