class OPSWORKS_Layers < CF_converter
  
  attr_accessor :name
  @@resource_id = 1
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Opsworks Layers
      opsworks = AWS::OpsWorks.new()
      layers = []
      all_resources[:opsworks_stacks].each do |stack|
        opsworks.client.describe_layers({:stack_id => stack[:stack_id]}).data[:layers].each do |layer|
          layer[:fake_id] = "layer#{layer[:name]}#{@@resource_id}"
          layer[:stack_name] = stack[:name]
          @@resource_id = @@resource_id + 1
          layers << layer
        end
      end if all_resources[:opsworks_stacks]
      all_resources.merge!({:opsworks_layers => layers})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:opsworks_layers => "Not supported in this region"})
      else
        all_errors.merge!({:opsworks_layers => e.message})
      end
      all_resources.merge!({:opsworks_layers => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:fake_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Layer Name: #{resource[:name]}\n" +
           "Short Name: #{resource[:shortname]}\n" +
           "Stack Name: #{resource[:stack_name]}"
  end

  def self.get_dependencies(resource, all_resources)
    sgs = []
    resource[:custom_security_group_ids].each do |sg|
      if all_resources[:security_groups]
        all_resources[:security_groups].each do |real_sg|
          sgs.push(real_sg) if sg.eql?(real_sg[:fake_id])
        end
      end
    end if resource[:custom_security_group_ids]
    instances = []
    all_resources[:opsworks_instances].each do |instance|
      instances.push(instance) if instance[:stack_id].eql?(resource[:stack_id])
    end if all_resources[:opsworks_instances]
    return { :security_groups => sgs, :opsworks_instances => instances }
  end

  def self.OutputList(resource)
    return {"Layer Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = OPSWORKS_Layers.ResourceName(resource)
    super(@name, "AWS::OpsWorks::Layer")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AutoAssignElasticIps" => resource[:auto_assign_elastic_ips].to_s})
    props.merge!({"AutoAssignPublicIps" => resource[:auto_assign_public_ips].to_s})
    props.merge!({"CustomInstanceProfileArn" => resource[:custom_instance_profile_arn]}) if resource[:custom_instance_profile_arn]
    props.merge!({"EnableAutoHealing" => resource[:enable_auto_healing].to_s})
    props.merge!({"InstallUpdatesOnBoot" => resource[:install_updates_on_boot].to_s}) if resource[:install_updates_on_boot]
    props.merge!({"Name" => resource[:name]}) if resource[:name]
    props.merge!({"Shortname" => resource[:shortname]}) if resource[:shortname]
    props.merge!({"Packages" => resource[:packages]}) if resource[:packages] && !resource[:packages].empty?
    props.merge!({"Type" => resource[:type]}) if resource[:type]

    props.merge!({"StackId" => ref_or_literal(:opsworks_stacks, resource[:stack_name], template, name_mappings)}) if resource[:stack_name]

    sgs = []
    resource[:custom_security_group_ids].each do |sg|
      sgs << ref_or_literal(:security_groups, sg, template, name_mappings)
    end if resource[:custom_security_group_ids]
    props.merge!({"CustomSecurityGroupIds" => sgs}) if resource[:custom_security_group_ids] && !sgs.empty?

    recipes = {}
    resource[:custom_recipes].each do |type, list|
      recipes["Configure"] = list if type == :configure && !list.empty?
      recipes["Deploy"] = list if type == :deploy && !list.empty?
      recipes["Setup"] = list if type == :setup && !list.empty?
      recipes["Shutdown"] = list if type == :shutdown && !list.empty?
      recipes["Undeploy"] = list if type == :undeploy && !list.empty?
    end if resource[:custom_recipes]
    props.merge!({"CustomRecipes" => recipes}) if !recipes.empty?

    attrs = {}
    resource[:attributes].each do |key,value|
      if value
        attrs[key] = value
      end
    end if resource[:attributes]
    props.merge!({"Attributes" => attrs}) if !attrs.empty?

    volumes = []
    resource[:volume_configurations].each do |volume|
      new_vol = {}
      new_vol["MountPoint"] = volume[:mount_point] if volume[:mount_point]
      new_vol["NumberOfDisks"] = volume[:number_of_disks].to_s if volume[:number_of_disks]
      new_vol["RaidLevel"] = volume[:raid_level] if volume[:raid_level]
      new_vol["Size"] = volume[:size] if volume[:size]
      new_vol["VolumeType"] = volume[:volume_type] if volume[:volume_type]
      new_vol["Iops"] = volume[:iops] if volume[:iops] && volume[:volume_type] && volume[:volume_type] == "io1"
      volumes << new_vol if !new_vol.empty?
    end if resource[:volume_configurations]
    props.merge!({"VolumeConfigurations" => volumes}) if !volumes.empty?

    # To make sure the apps are available for deployment, make the layer dependent on all apps in this stack
    depends_on = []
    if template[:selected_resources] &&  template[:selected_resources][:opsworks_apps]
      template[:selected_resources][:opsworks_apps].each do |app|
         depends_on << app[:logical_name] if app[:stack_id].eql?(resource[:stack_id])
      end
    end

    defn = { "Type" => @cf_type, "Properties" => props }
    defn["DependsOn"] = depends_on if !depends_on.empty?

    return @cf_definition.deep_merge({ OPSWORKS_Layers.map_resource_name(@name, name_mappings) => defn })
  end
    
end
