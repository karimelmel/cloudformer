class Enis < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the network interface resources we care about
      ec2 = AWS::EC2.new(:region => region)
      enis = []
      ec2.client.describe_network_interfaces().data[:network_interface_set].each do |eni|
        if (!eni[:attachment])
          enis.push(eni)
        # Only allow the ENI if this is not device 0 - we will fix this when we support all ENI and EIP configurations
        elsif eni[:owner_id].eql?(eni[:attachment][:instance_owner_id]) && eni[:attachment][:device_index] != 0
          attachment = eni[:attachment]
          attachment.delete(:attach_time)
          enis.push(eni)
        end
      end
      all_resources.merge!({:enis => enis})
    rescue => e
      all_errors.merge!({:enis => e.message})
      all_resources.merge!({:enis => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:network_interface_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    ec2_resources = []
    all_resources[:instances].each do |instance|
      ec2_resources.push(instance) if instance[:instance_id].eql?(resource[:attachment][:instance_id]) if resource[:attachment]
    end 

    return { :instances => ec2_resources }
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" + "#{tag[:key]}: #{tag[:value]} " if tag[:value] != nil
      end
    end          
    return "NetworkInterfaceId: #{resource[:network_interface_id]} \n" +
           "Description: #{resource[:description]} \n" +
           "VPCId: #{resource[:vpc_id]} \n" +
           "SubnetId: #{resource[:subnet_id]} " +
           tags
  end

  def self.OutputList(resource)
    return {"Elastic Network Interface Id" => "ENI,Ref",
            "Primary Private IP Address" => "PrimaryPrivateIpAddress,GetAtt,PrimaryPrivateIpAddress",
            "Secondary Private IP Addresses" => "SecondaryPrivateIpAddresses,GetAtt,SecondaryPrivateIpAddresses"}
  end

  def initialize(resource)
    @name = Enis.ResourceName(resource)
    super(@name, "AWS::EC2::NetworkInterface")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]}) if resource[:description]
    props.merge!({"SourceDestCheck" => resource[:source_dest_check].to_s()}) if resource[:source_dest_check]
    props.merge!({"SubnetId" => ref_or_literal(:subnets, resource[:subnet_id], template, name_mappings)}) if resource[:subnet_id]

    ip_addresses = []
    if resource[:private_ip_addresses_set]
      resource[:private_ip_addresses_set].each do |ip|
        ip_addresses << {"PrivateIpAddress" => ip[:private_ip_address].to_s(), "Primary" => ip[:primary].to_s()}
      end
      props.merge!({"PrivateIpAddresses" => ip_addresses}) if !ip_addresses.empty?
    else
      props.merge!({"PrivateIpAddress" => resource[:private_ip_address]}) if resource[:private_ip_address]
    end

    if resource[:groups]
      groups = []
      resource[:groups].each do |group|
        if group[:group_id]
          groups.push(ref_or_literal(:security_groups, group[:group_id], template, name_mappings))
        end
      end
      props.merge!({"GroupSet" => groups}) if groups != []
    end

    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    return @cf_definition.deep_merge({ Enis.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
