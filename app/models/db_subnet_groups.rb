class DB_Subnet_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RDS DB subnet groups we care about
      rds = AWS::RDS.new(:region => region)
      sgs = rds.client.describe_db_subnet_groups().data[:db_subnet_groups]
      sgs.each do |sg|
        begin
          # in order to find the account id, find an EC2 security group in the account
          ec2 = AWS::EC2::new(:region => region)
          arn = "arn:aws:rds:#{region}:#{ec2.security_groups.first.owner_id}:subgrp:#{sg[:db_subnet_group_name]}"
          sg.merge!(rds.client.list_tags_for_resource(:resource_name => arn))
        rescue => e
          all_errors.merge!({:db_parameter_groups => "Failed to get tags for DB subnet group #{full_pg[:db_subnet_group_name]}"})
        end
      end
      all_resources.merge!({:db_subnet_groups => sgs})
    rescue => e
      all_errors.merge!({:db_subnet_groups => e.message})
      all_resources.merge!({:db_subnet_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "dbsubnet" + resource[:db_subnet_group_name].tr('^A-Za-z0-9', '')
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
    @name = DB_Subnet_Groups.ResourceName(resource)
    super(@name, "AWS::RDS::DBSubnetGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DBSubnetGroupDescription" => resource[:db_subnet_group_description]})

    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets << ref_or_literal(:subnets, subnet[:subnet_identifier], template, name_mappings)
      end
    end
    props.merge!({"SubnetIds" => subnets}) if !subnets.empty?

    tags = []
    if resource[:tag_list]
      resource[:tag_list].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ DB_Subnet_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
