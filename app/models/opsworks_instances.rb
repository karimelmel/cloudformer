class OPSWORKS_Instances < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Opsworks Layers
      opsworks = AWS::OpsWorks.new()
      instances = []
      all_resources[:opsworks_stacks].each do |stack|
        opsworks.client.describe_instances({:stack_id => stack[:stack_id]}).data[:instances].each do |instance|
          instance[:stack_name] = stack[:name]
          layer_names = []
          instance[:layer_ids].each do |layer_id|
            all_resources[:opsworks_layers].each do |layer|
              layer_names << layer[:name] if layer[:layer_id].eql?(layer_id)
            end if all_resources[:opsworks_layers]
          end
          instance[:layer_names] = layer_names
          instances << instance
        end
      end if all_resources[:opsworks_stacks]
      all_resources.merge!({:opsworks_instances => instances})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:opsworks_instances => "Not supported in this region"})
      else
        all_errors.merge!({:opsworks_instances => e.message})
      end
      all_resources.merge!({:opsworks_instances => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:instance_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Stack Name: #{resource[:stack_name]}\n" +
           "Instance Id: #{resource[:instance_id]}\n" +
           "EC2 Instance Id: #{resource[:ec2_instance_id]}\n" +
           "Host Name: #{resource[:hostname]}"
  end

  def self.get_dependencies(resource, all_resources)
    sgs = []
    resource[:security_group_ids].each do |sg|
      if all_resources[:security_groups]
        all_resources[:security_groups].each do |real_sg|
          sgs.push(real_sg) if sg.eql?(real_sg[:fake_id])
        end
      end
    end if resource[:security_group_ids]
    return { :security_groups => sgs }
  end

  def self.OutputList(resource)
    return {"Instance Id" => "Name,Ref"}
  end

  def initialize(resource)
    @name = OPSWORKS_Instances.ResourceName(resource)
    super(@name, "AWS::OpsWorks::Instance")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"AmiId" => resource[:ami_id]}) if resource[:ami_id] && !resource[:os].eql?("Amazon Linux")
    props.merge!({"Architecture" => resource[:architecture]}) if resource[:architecture]
    props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone]
    props.merge!({"InstallUpdatesOnBoot" => resource[:install_updates_on_boot].to_s}) if resource[:install_updates_on_boot]
    props.merge!({"InstanceType" => resource[:instance_type]}) if resource[:instance_type]
    props.merge!({"Name" => resource[:name]}) if resource[:name]
    props.merge!({"Os" => resource[:os]}) if resource[:os]
    props.merge!({"RootDeviceType" => resource[:root_device_type]}) if resource[:root_device_type]
    props.merge!({"SshKeyName" => resource[:ssh_key_name]}) if resource[:ssh_key_name]
    
    props.merge!({"StackId" => ref_or_literal(:opsworks_stacks, resource[:stack_name], template, name_mappings)}) if resource[:stack_name]
    props.merge!({"SubnetId" => ref_or_literal(:subnets, resource[:subnet_id], template, name_mappings)}) if resource[:subnet_id]

    layers = []
    resource[:layer_names].each do |layer|
      layers << ref_or_literal(:opsworks_layers, layer, template, name_mappings)
    end if resource[:layer_ids]
    props.merge!({"LayerIds" => layers}) if !layers.empty?

    return @cf_definition.deep_merge({ OPSWORKS_Instances.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})

  end
end
