class DB_Parameter_Groups < CF_converter
  
  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RDS DB parameter groups we care about
      rds = AWS::RDS.new(:region => region)
      pgs = rds.client.describe_db_parameter_groups().data[:db_parameter_groups]
      all_pgs = []
      pgs.each do |pg|
        if !pg[:db_parameter_group_name].starts_with?("default")
          full_pg = pg.clone
          full_params = rds.client.describe_db_parameters(:db_parameter_group_name => pg[:db_parameter_group_name]).data[:parameters]
          clean_params = {}
          full_params.each do |param|
            clean_params.merge!({param[:parameter_name] => param[:parameter_value]}) if param[:parameter_value] != nil && param[:is_modifiable]
          end
          full_pg.merge!({:parameters => clean_params})
          begin
            # in order to find the account id, find an EC2 security group in the account
            ec2 = AWS::EC2::new(:region => region)
            arn = "arn:aws:rds:#{region}:#{ec2.security_groups.first.owner_id}:pg:#{full_pg[:db_parameter_group_name]}"
            full_pg.merge!(rds.client.list_tags_for_resource(:resource_name => arn))
          rescue => e
            all_errors.merge!({:db_parameter_groups => "Failed to get tags for DB Parameter group #{full_pg[:db_parameter_group_name]}"})
          end
          all_pgs << full_pg
        end
      end
      all_resources.merge!({:db_parameter_groups => all_pgs})
    rescue => e
      all_errors.merge!({:db_parameter_groups => e.message})
      all_resources.merge!({:db_parameter_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "dbpg" + resource[:db_parameter_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:description]}\n " +
           "Family: #{resource[:db_parameter_group_family]}"
  end  
  
  def self.OutputList(resource)
    return {"Parameter Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = DB_Parameter_Groups.ResourceName(resource)
    super(@name, "AWS::RDS::DBParameterGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})
    props.merge!({"Family" => resource[:db_parameter_group_family]})
    props.merge!({"Parameters" => resource[:parameters]}) if resource[:parameters]

    tags = []
    if resource[:tag_list]
      resource[:tag_list].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ DB_Parameter_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
