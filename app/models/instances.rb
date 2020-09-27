class Instances < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EC2 instances we care about
      ec2 = AWS::EC2.new(:region => region)
      all_instances = []
      all_reservations = ec2.client.describe_instances().data[:reservation_set]
      all_reservations.each do |res|
        if res[:instances_set]
          res[:instances_set].each do |instance|
            attributes = ec2.client.describe_instance_attribute({:instance_id => instance[:instance_id], :attribute => "instanceInitiatedShutdownBehavior"})
            full_res = instance.clone
            full_res[:instance_initiated_shutdown_behavior] = attributes[:instance_initiated_shutdown_behavior] if attributes[:instance_initiated_shutdown_behavior]
            all_instances << full_res
          end
        end
      end
      # Remove all datetime entries
      all_instances.each do |i|
        i.reject!{ |k| k == :launch_time }
        if i[:block_device_mapping]
          i[:block_device_mapping].each do |bdm|
            bdm[:ebs].reject!{ |k| k == :attach_time } if bdm[:ebs]
          end
        end
        if i[:network_interface_set]
          i[:network_interface_set].each do |eni|
            eni[:attachment].reject!{ |k| k == :attach_time } if eni[:attachment]
          end
        end
      end
      # Remove this host if we are running on EC2
      # Remove auto scaled instances
      # Remove opsworks instances
      begin
        all_valid_instances = []
        client = HTTPClient.new
        this_instance = client.get_content("http://169.254.169.254/latest/meta-data/instance-id")
        all_instances.each do |instance|
          found = instance[:instance_id].eql?(this_instance)
          if !found
            as = AWS::AutoScaling.new(:region => region)
            as.client.describe_auto_scaling_groups().data[:auto_scaling_groups].each do |asg|
              asg[:instances].each do |as_instance|
                found = found || as_instance[:instance_id].eql?(instance[:instance_id])
              end
            end
          end
          if !found
            begin
              opsworks = AWS::OpsWorks.new()
              opsworks.client.describe_stacks().data[:stacks].each do |stack|
                opsworks.client.describe_instances({:stack_id => stack[:stack_id]}).data[:instances].each do |opsworks_instance|
                  found = found || opsworks_instance[:ec2_instance_id].eql?(instance[:instance_id])
                end
              end
            rescue AWS::OpsWorks::Errors::UnrecognizedClientException => e
              p e.message
              p "Failed to filter EC2 instance from existing OpsWorks stacks: This error may be a result of OpsWorks not being available in this region."
              p "Skipping OpsWorks instance filtering"
            end
          end
          all_valid_instances << instance if !found
        end
      rescue => e
        p e.message
        p "Failed to filter EC2 instance"
      end
      all_resources.merge!({:instances => all_valid_instances})
    rescue => e
      all_errors.merge!({:instances => e.message})
      all_resources.merge!({:instances => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "instance" + resource[:instance_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    sgResources = []
    volResources = []
    eniResources = []

    if all_resources[:security_groups]
      all_resources[:security_groups].each do |sg|
        if resource[:group_set]
          resource[:group_set].each do |group|
            thegroup = {}
            if resource[:subnet_id]
              thegroup = sg if group[:group_id] && group[:group_id] == sg[:group_id] 
            else
              thegroup = sg if group[:group_name] && group[:group_name] == sg[:group_name]
            end
            sgResources.push(thegroup) if !thegroup.empty?
          end
        end
      end      
    end
    if resource[:block_device_mapping]
      resource[:block_device_mapping].each do |vol|
        all_resources[:volumes].each do |all_vol|
          volResources.push(all_vol) if vol[:ebs][:volume_id] && all_vol[:volume_id] == vol[:ebs][:volume_id]
        end
      end
    end

    all_resources[:enis].each do |eni|
      eniResources.push(eni) if resource[:instance_id].eql?(eni[:attachment][:instance_id]) if eni[:attachment]
    end 

    return { :security_groups => sgResources, :volumes => volResources, :enis => eniResources }
  end
  
  def self.get_resource_attributes(resource)

    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" + "#{tag[:key]}: #{tag[:value]}"
      end
    end          
    vpc = ""
    vpc = "\nVPC: #{resource[:vpc_id]}" if resource[:vpc_id]
    vpc = vpc + "\nSubnet: #{resource[:subnet_id]}" if resource[:subnet_id]
    
    return "Image Id: #{resource[:image_id]} \n" +
           "Instance Type: #{resource[:instance_type]} \n" +
           "Availability Zone: #{resource[:placement][:availability_zone]} \n" +
           "Key Name: #{resource[:key_name]} \n" +
           "Private DNS: #{resource[:private_dns_name]} \n" +
           "Private IP: #{resource[:private_ip_address]} \n" +
           "Public DNS: #{resource[:dns_name]} \n" +
           "Public IP: #{resource[:ip_address]}" + vpc + tags
  end

  def self.OutputList(resource)
    return {"Instance Id" => "Id,Ref",
            "Availability Zone" => "AZ,GetAtt,AvailabilityZone",
            "Public IP Address" => "IP,GetAtt,PublicIp",
            "Public DNS Name" => "PublicDNSName,GetAtt,PublicDnsName",
            "Private IP Address" => "PrivateIP,GetAtt,PrivateIp",
            "Private DNS Name" => "PrivateDNSName,GetAtt,PrivateDnsName"}
  end

  def initialize(resource)
    @name = Instances.ResourceName(resource)
    super(@name, "AWS::EC2::Instance")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DisableApiTermination" => "false"})
    props.merge!({"InstanceInitiatedShutdownBehavior" => resource[:instance_initiated_shutdown_behavior][:value]}) if resource[:instance_initiated_shutdown_behavior] && resource[:instance_initiated_shutdown_behavior][:value]
    props.merge!({"EbsOptimized" => resource[:ebs_optimized].to_s}) if resource[:ebs_optimized]
    props.merge!({"IamInstanceProfile" => resource[:iam_instance_profile][:arn]}) if resource[:iam_instance_profile] 
    props.merge!({"ImageId" => resource[:image_id]}) if resource[:image_id] 
    props.merge!({"InstanceType" => resource[:instance_type]}) if resource[:instance_type] 
    props.merge!({"KernelId" => resource[:kernel_id]}) if resource[:kernel_id]
    props.merge!({"KeyName" => resource[:key_name]}) if resource[:key_name]
    props.merge!({"Monitoring" => (resource[:monitoring][:state].to_s == "enabled").to_s}) if resource[:monitoring]
    props.merge!({"PlacementGroupName" => resource[:placement][:group_name]}) if resource[:placement] && resource[:placement][:group_name]
    props.merge!({"RamDiskId" => resource[:ramdisk_id]}) if resource[:ramdisk_id]
    props.merge!({"Tenancy" => resource[:placement][:tenancy]}) if resource[:placement] && resource[:placement][:tenancy] && resource[:placement][:tenancy] != "default"

    tags = []
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    if resource[:block_device_mapping]
      volumes = []
      resource[:block_device_mapping].each do |volume|
        if volume[:device_name] != resource[:root_device_name] && volume[:ebs]
          volumes.push({
            "Device" => volume[:device_name],
            "VolumeId" => ref_or_literal(:volumes, volume[:ebs][:volume_id], template, name_mappings)
          })
        end
        props.merge!({"Volumes" => volumes}) if !volumes.empty?
      end      
    end

    if resource[:network_interface_set]
      interfaces = []
      resource[:network_interface_set].each do |xface|
        interface = {}
        interface.merge!({"DeleteOnTermination" => "true"})
        interface.merge!({"Description" => xface[:description]}) if xface[:description]
        interface.merge!({"DeviceIndex" => xface[:attachment][:device_index]}) if xface[:attachment] && xface[:attachment][:device_index]
        interface.merge!({"SubnetId" => ref_or_literal(:subnets, xface[:subnet_id], template, name_mappings)}) if xface[:subnet_id]

        if xface[:private_ip_addresses_set]
          ips = []
          xface[:private_ip_addresses_set].each do |ip|
            if ip[:primary]
              ips.push({"PrivateIpAddress" => ip[:private_ip_address], "Primary" => ip[:primary] ? "true" : "false" }) if ip[:private_ip_address]
            else
              ips.push({"PrivateIpAddress" => ip[:private_ip_address], "Primary" => "false" }) if ip[:private_ip_address]
            end
          end
          interface.merge!({"PrivateIpAddresses" => ips}) if !ips.empty?
        end

        if xface[:group_set]
          groups = []
          xface[:group_set].each do |group|
            groups.push(ref_or_literal(:security_groups, group[:group_id], template, name_mappings)) if group[:group_id]
          end
          interface.merge!({"GroupSet" => groups}) if !groups.empty?
        end

        if xface[:association] && xface[:association][:ip_owner_id] == "amazon"
          interface.merge!({"AssociatePublicIpAddress" => "true"})
        end

        # Only save this interface if it is index 0 - others will be captured by ENIs and attachments
        # This is a temporary fix until we support all configurations of ENI and EIP
        # interfaces.push(interface)
        interfaces.push(interface) if xface[:attachment] && xface[:attachment][:device_index] && xface[:attachment][:device_index] == 0
      end
      props.merge!({"NetworkInterfaces" => interfaces}) if !interfaces.empty?
    else
      props.merge!({"AvailabilityZone" => resource[:placement][:availability_zone]}) if resource[:placement][:availability_zone]
      props.merge!({"SourceDestCheck" => resource[:source_dest_check].to_s})
      if resource[:group_set]
        groups = []
        resource[:group_set].each do |group|
          groups.push(ref_or_literal(:security_groups, group[:group_name], template, name_mappings)) if group[:group_name]
        end
        props.merge!({"SecurityGroups" => groups}) if !groups.empty?
      end
    end

    return @cf_definition.deep_merge({ Instances.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
