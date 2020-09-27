class REDSHIFT_Subnet_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RedShift subnet groups we care about
      redshift = AWS::Redshift.new(:region => region)
      sgs = redshift.client.describe_cluster_subnet_groups().data[:cluster_subnet_groups]
      all_resources.merge!({:redshift_subnet_groups => sgs})
    rescue => e
      if region.eql?("us-west-1") || region.eql?("sa-east-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:redshift_subnet_groups => "Not supported in this region"})
      else
        all_errors.merge!({:redshift_subnet_groups => e.message})
      end
      all_resources.merge!({:redshift_subnet_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "clusubnet" + resource[:cluster_subnet_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets << subnet[:subnet_identifier]
      end
    end
    return "Description: #{resource[:db_subnet_group_description]}\n " +
           "Subnets: #{subnets.to_s}"
  end  
  
  def self.OutputList(resource)
    return {"Subnet Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = REDSHIFT_Subnet_Groups.ResourceName(resource)
    super(@name, "AWS::Redshift::ClusterSubnetGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})

    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets << ref_or_literal(:subnets, subnet[:subnet_identifier], template, name_mappings)
      end
    end
    props.merge!({"SubnetIds" => subnets}) if !subnets.empty?

    return @cf_definition.deep_merge({ REDSHIFT_Subnet_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
