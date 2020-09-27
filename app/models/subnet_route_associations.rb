class Subnet_route_associations < CF_converter
  
  attr_accessor :name
  @@subnet_assoc_id = 1

  def self.post_selection(template)
    subnet_route_entries = []
    if template.selected_resources && template.selected_resources[:route_tables]
      template.selected_resources[:route_tables].each do |rt|
        if rt[:association_set]
          rt[:association_set].each do |assoc|
            assoc_entry = assoc.clone
            assoc_entry.merge!({:name=>"subnetroute#{@@subnet_assoc_id}"})
            subnet_route_entries << assoc_entry if assoc[:subnet_id]
            @@subnet_assoc_id = @@subnet_assoc_id + 1
          end
        end
      end
    end
    template.selected_resources.merge!({:subnet_route_associations => subnet_route_entries})
  end

  def initialize(resource)
    @name = resource[:name]
    super(@name, "AWS::EC2::SubnetRouteTableAssociation")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"RouteTableId" => ref_or_literal(:route_tables, resource[:route_table_id], template, name_mappings)}) if resource[:route_table_id] 
    props.merge!({"SubnetId" => ref_or_literal(:subnets, resource[:subnet_id], template, name_mappings)}) if resource[:subnet_id] 

    return @cf_definition.deep_merge({ Subnet_route_associations.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
