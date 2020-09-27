class DB_Security_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RDS DB security groups we care about
      rds = AWS::RDS.new(:region => region)
      sgs = rds.client.describe_db_security_groups().data[:db_security_groups]
      sgs.each do |sg|
        begin
          # in order to find the account id, find an EC2 security group in the account
          ec2 = AWS::EC2::new(:region => region)
          arn = "arn:aws:rds:#{region}:#{ec2.security_groups.first.owner_id}:secgrp:#{sg[:db_security_group_name]}"
          sg.merge!(rds.client.list_tags_for_resource(:resource_name => arn))
        rescue => e
          all_errors.merge!({:db_parameter_groups => "Failed to get tags for DB security roup #{full_pg[:db_security_group_name]}"})
        end
      end
      all_resources.merge!({:db_security_groups => sgs})
    rescue => e
      all_errors.merge!({:db_security_groups => e.message})
      all_resources.merge!({:db_security_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "dbsg" + resource[:db_security_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:db_security_group_description]}"
  end  
  
  def self.OutputList(resource)
    return {"Security Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = DB_Security_Groups.ResourceName(resource)
    super(@name, "AWS::RDS::DBSecurityGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"GroupDescription" => resource[:db_security_group_description]})
     
    ingress = []
    if resource[:ec2_security_groups]
      resource[:ec2_security_groups].each do |rule|
        lrule = {
          # "EC2SecurityGroupId" => ref_or_literal(:security_groups, rule[:ec2_security_group_id], template, name_mappings),
          "EC2SecurityGroupName" => ref_or_literal(:security_groups, rule[:ec2_security_group_name], template, name_mappings),
          "EC2SecurityGroupOwnerId" => rule[:ec2_security_group_owner_id].to_s,
        }
        ingress.push(lrule)
      end      
    end

    if resource[:ip_ranges]
      resource[:ip_ranges].each do |rule|
        lrule = {
          "CIDRIP" => rule[:cidrip],
        }
        ingress.push(lrule)
      end      
    end

    tags = []
    if resource[:tag_list]
      resource[:tag_list].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    props.merge!({"DBSecurityGroupIngress" => ingress}) if !ingress.empty?
    return @cf_definition.deep_merge({ DB_Security_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
