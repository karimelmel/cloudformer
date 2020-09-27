class Launch_Configs < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Auto Scaling Launch Configs we care about
      as = AWS::AutoScaling.new(:region => region)
      lcs = []

      launch_configurations = []
      next_token = nil

      loop do
        launch_configurations_data = next_token.nil? ? as.client.describe_launch_configurations().data : as.client.describe_launch_configurations(:next_token => next_token).data
        launch_configurations += launch_configurations_data[:launch_configurations]
        next_token = launch_configurations_data[:next_token]
        break if next_token.nil?
      end

     launch_configurations.each do |lc|
        fixed_lc = lc.clone
        fixed_lc.reject!{ |k| k == :created_time }
        lcs << fixed_lc
      end
      all_resources.merge!({:launch_configs => lcs})
    rescue => e
      all_errors.merge!({:launch_configs => e.message})
      all_resources.merge!({:launch_configs => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "lc" + resource[:launch_configuration_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    sgResources = []
    if all_resources[:security_groups]
      all_resources[:security_groups].each do |sg|
        sgResources.push(sg) if resource[:security_groups].include?(sg[:group_name])
      end      
    end
    return { :security_groups => sgResources }
  end
  
  def self.get_resource_attributes(resource)
    return "Image Id: #{resource[:image_id]} \n" +
           "Instance Type: #{resource[:instance_type]} \n" +
           "Key Name: #{resource[:key_name]} \n" +
           "Security Groups: #{resource[:security_groups]}"

  end

  def self.OutputList(resource)
    return {"Launch Config Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Launch_Configs.ResourceName(resource)
    super(@name, "AWS::AutoScaling::LaunchConfiguration")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AssociatePublicIpAddress" => resource[:associate_public_ip_address]}) if resource[:associate_public_ip_address]
    props.merge!({"ImageId" => resource[:image_id]}) if resource[:image_id]
    props.merge!({"InstanceType" => resource[:instance_type]}) if resource[:instance_type]
    props.merge!({"KernelId" => resource[:kernel_id]}) if resource[:kernel_id] 
    props.merge!({"KeyName" => resource[:key_name]}) if resource[:key_name]
    props.merge!({"RamDiskId" => resource[:ramdisk_id]}) if resource[:ramdisk_id]
    props.merge!({"EbsOptimized" => resource[:ebs_optimized]}) if resource[:ebs_optimized]
    props.merge!({"IamInstanceProfile" => resource[:iam_instance_profile]}) if resource[:iam_instance_profile]
    props.merge!({"InstanceMonitoring" => resource[:instance_monitoring][:enabled].to_s}) if resource[:instance_monitoring][:enabled]
    props.merge!({"PlacementTenancy" => resource[:placement_tenancy]}) if resource[:placement_tenancy]
    props.merge!({"SpotPrice" => resource[:spot_price]}) if resource[:spot_price]

    props.merge!({"ClassicLinkVPCId" => resource[:classic_link_vpc_id]}) if resource[:classic_link_vpc_id]
    if resource[:classic_link_vpc_security_groups]
      resource[:classic_link_vpc_security_groups].each do |classic_link_vpc_security_group|
        props.merge!({"ClassicLinkVPCSecurityGroups" => classic_link_vpc_security_group[:items]})
      end
    end
    if resource[:security_groups]
      groups = []
      resource[:security_groups].each do |group|
        groups.push(ref_or_literal(:security_groups, group, template, name_mappings))        
      end
      props.merge!({"SecurityGroups" => groups}) if !groups.empty?
    end

    if resource[:block_device_mappings]
      bdms = []
      resource[:block_device_mappings].each do |bdm|
        new_bdm = {}
        new_bdm.merge!({"VirtualName" => bdm[:virtual_name]}) if bdm[:virtual_name]
        new_bdm.merge!({"DeviceName" => bdm[:device_name]}) if bdm[:device_name]
        if bdm[:ebs]
          new_ebs = {}
          new_ebs.merge!({"SnapshotId" => bdm[:ebs][:snapshot_id]}) if bdm[:ebs][:snapshot_id]
          new_ebs.merge!({"VolumeSize" => bdm[:ebs][:volume_size]}) if bdm[:ebs][:volume_size]
          new_bdm.merge!({"Ebs" => new_ebs}) if !new_ebs.empty?
        end
        bdms << new_bdm if !new_bdm.empty?
      end
      props.merge!({"BlockDeviceMappings" => bdms}) if !bdms.empty?
    end

    return @cf_definition.deep_merge({ Launch_Configs.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
