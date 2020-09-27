class VPC_Peers < CF_converter

  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the VPC peering connection resources we care about
      ec2 = AWS::EC2.new(:region => region)
      peering_conns = []
      ec2.client.describe_vpc_peering_connections().data[:vpc_peering_connection_set].each do |peer|
	peer_fixed = peer.clone
        peer_fixed.reject!{ |k| k == :expiration_time }
        peering_conns << peer_fixed
      end
      all_resources.merge!({:vpc_peers => peering_conns})
    rescue => e
      all_errors.merge!({:vpc_peers => e.message})
      all_resources.merge!({:vpc_peers => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:vpc_peering_connection_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" + "#{tag[:key]}: #{tag[:value]} " if tag[:value] != nil
      end
    end          
    return "VPCPeeringConnectionId: #{resource[:vpc_peering_connection_id]} \n" +
           tags
  end

  def self.OutputList(resource)
    return {"VPC Peering Connection Id" => "Id,Ref"}
  end

  def initialize(resource)
    @name = VPC_Peers.ResourceName(resource)
    super(@name, "AWS::EC2::VPCPeeringConnection")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    if resource[:tag_set]
      tags = []
      if resource[:tag_set]
        resource[:tag_set].each do |tag|
          tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
        end
      end          
      props.merge!({"Tags" => tags}) if !tags.empty?      
    end

    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:requester_vpc_info][:vpc_id], template, name_mappings)}) if resource[:requester_vpc_info] && resource[:requester_vpc_info][:vpc_id]
    props.merge!({"PeerVpcId" => ref_or_literal(:vpcs, resource[:accepter_vpc_info][:vpc_id], template, name_mappings)}) if resource[:accepter_vpc_info] && resource[:accepter_vpc_info][:vpc_id]

    return @cf_definition.deep_merge({ VPC_Peers.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
