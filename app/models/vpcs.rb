class Vpcs < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the VPC resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_vpcs = ec2.client.describe_vpcs().data[:vpc_set]
      all_vpcs.each do |vpc|
        vpc_attr = ec2.client.describe_vpc_attribute({:vpc_id => vpc[:vpc_id], :attribute => "enableDnsSupport"})
        vpc[:enable_dns_support] = vpc_attr[:enable_dns_support]
        vpc_attr = ec2.client.describe_vpc_attribute({:vpc_id => vpc[:vpc_id], :attribute => "enableDnsHostnames"})
        vpc[:enable_dns_hostnames] = vpc_attr[:enable_dns_hostnames]
      end
      all_resources.merge!({:vpcs => all_vpcs})
    rescue => e
      all_errors.merge!({:vpcs => e.message})
      all_resources.merge!({:vpcs => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:vpc_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    vpc_id = resource[:vpc_id]

    # Find all related subnets
    subnets = []
    all_resources[:subnets].each do |subnet|
      subnets << subnet if subnet[:vpc_id] == vpc_id
    end if all_resources[:subnets]

    # Find all related igws
    igws = []
    all_resources[:igws].each do |igw|
      igw[:attachment_set].each do |attach|
        igws << igw if attach[:vpc_id] == vpc_id
      end if igw[:attachment_set]
    end if all_resources[:igws]

    # Find all related vgws
    vgws = []
    all_resources[:vgws].each do |vgw|
      vgw[:attachments].each do |attach|
        vgws << vgw if attach[:vpc_id] == vpc_id
      end if vgw[:attachments]
    end if all_resources[:vgws]

    # Find all cgws connected to selected vgws
    cgws = []
    vpncs = []
    all_resources[:vpn_connections].each do |vpnc|
      vgws.each do |vgw|
        all_resources[:cgws].each do |cgw|
          cgws << cgw if cgw[:customer_gateway_id] == vpnc[:customer_gateway_id] && vgw[:vpn_gateway_id] == vpnc[:vpn_gateway_id]
          vpncs << vpnc if cgw[:customer_gateway_id] == vpnc[:customer_gateway_id] && vgw[:vpn_gateway_id] == vpnc[:vpn_gateway_id]
        end if all_resources[:cgws]
      end
    end if all_resources[:vpn_connections]

    # Find all related DHCP options
    dhcps = []
    all_resources[:dhcps].each do |dhcp|
      dhcps << dhcp if dhcp[:dhcp_options_id] == resource[:dhcp_options_id]
    end if all_resources[:dhcps]

    # Find all related network ACLs
    nacls = []
    all_resources[:network_acls].each do |nacl|
      nacls << nacl if nacl[:vpc_id] == vpc_id
    end if all_resources[:network_acls]

    # Find all related Route Tables
    rts = []
    all_resources[:route_tables].each do |rt|
      rts << rt if rt[:vpc_id] == vpc_id
    end if all_resources[:route_tables]

    return {:subnets => subnets, :igws => igws, :vgws => vgws, :cgws => cgws, :vpn_connections => vpncs, :dhcps => dhcps, :network_acls => nacls, :route_tables => rts}
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" "#{tag[:key]}: #{tag[:value]} " if tag[:value] != nil
      end
    end          
    return "CidrBlock: #{resource[:cidr_block]} \nDefault VPC: #{resource[:is_default]} " + tags
  end

  def self.OutputList(resource)
    return {"Vpc Id" => "Id,Ref",
            "Default Network ACL" => "DefaultNetworkAcl,GetAtt,DefaultNetworkAcl",
            "Default Security Group" => "DefaultSecurityGroup,GetAtt,DefaultSecurityGroup"}
  end

  def initialize(resource)
    @name = Vpcs.ResourceName(resource)
    super(@name, "AWS::EC2::VPC")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"CidrBlock" => resource[:cidr_block]}) if resource[:cidr_block]
    props.merge!({"InstanceTenancy" => resource[:instance_tenancy]}) if resource[:instance_tenancy]
    props.merge!({"EnableDnsSupport" => resource[:enable_dns_support][:value].to_s()})
    props.merge!({"EnableDnsHostnames" => resource[:enable_dns_hostnames][:value].to_s()})

    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    return @cf_definition.deep_merge({ Vpcs.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
