class Databases < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RDS databases we care about
      rds = AWS::RDS.new(:region => region)
      dbs = []
      rds.client.describe_db_instances().data[:db_instances].each do |db|
        full_db = db.clone
        full_db.reject!{ |k| k == :instance_create_time }
        full_db.reject!{ |k| k == :latest_restorable_time }
        begin
          # in order to find the account id, find an EC2 security group in the account
          ec2 = AWS::EC2::new(:region => region)
          db_arn = "arn:aws:rds:#{region}:#{ec2.security_groups.first.owner_id}:db:#{db[:db_instance_identifier]}"
          full_db.merge!(rds.client.list_tags_for_resource(:resource_name => db_arn))
        rescue => e
          all_errors.merge!({:dbs => "Failed to get tags for DB #{db[:db_instance_identifier]}"})
        end
        dbs << full_db
      end
      all_resources.merge!({:dbs => dbs})
    rescue => e
      all_errors.merge!({:dbs => e.message})
      all_resources.merge!({:dbs => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "rds" + resource[:db_instance_identifier].tr('^A-Za-z0-9', '')
  end
    
  def self.get_dependencies(resource, all_resources)
    dbsgResources = []
    if resource[:db_security_groups] && !resource[:db_subnet_group]
      resource[:db_security_groups].each do |sg|
        all_resources[:db_security_groups].each do |all_sg|
          dbsgResources.push(all_sg) if all_sg[:db_security_group_name] == sg[:db_security_group_name]
        end
      end
    end
    sgResources = []
    if resource[:vpc_security_groups]
      resource[:vpc_security_groups].each do |sg|
        all_resources[:security_groups].each do |all_sg|
          sgResources.push(all_sg) if all_sg[:fake_id] == sg[:vpc_security_group_id]
        end
      end
    end
    dbsubnetResources = []
    if resource[:db_subnet_group] && resource[:db_subnet_group][:db_subnet_group_name]
      all_resources[:db_subnet_groups].each do |all_sg|
        dbsubnetResources.push(all_sg) if all_sg[:db_subnet_group_name] == resource[:db_subnet_group][:db_subnet_group_name]
      end
    end
    dbpgResources = []
    if resource[:db_parameter_groups]
      resource[:db_parameter_groups].each do |pg|
        all_resources[:db_parameter_groups].each do |all_pg|
          dbpgResources.push(all_pg) if all_pg[:db_parameter_group_name] == pg[:db_parameter_group_name]
        end
      end
    end
    return { :db_security_groups => dbsgResources, :security_groups => sgResources, :db_subnet_groups => dbsubnetResources, :db_parameter_groups => dbpgResources }
  end

  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_list]
      resource[:tag_list].each do |tag|
        tags = tags + "\n" "#{tag[:key]}: #{tag[:value]} "
      end
    end          
    return "Class: #{resource[:db_instance_class]} \n" +
           "Engine: #{resource[:engine]} \n" +
           "Engine Version: #{resource[:engine_version]} \n" +
           "Availability Zone: #{resource[:availability_zone]} \n" +
           "Multi-AZ: #{resource[:multi_az]}" + tags
  end

  def self.OutputList(resource)
    return {"Database Name" => "Name,Ref",
            "Database Endpoint Address" => "Endpoint,GetAtt,Endpoint.Address",
            "Database Port" => "Port,GetAtt,Endpoint.Port",
            "JDBC Connection String" => "Connect,Join,,jdbc:mysql://,GetAtt,Endpoint.Address,:,GetAtt,Endpoint.Port,/,MyDatabase"}
  end


  def initialize(resource)
    @name = Databases.ResourceName(resource)
    super(@name, "AWS::RDS::DBInstance")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AllocatedStorage" => resource[:allocated_storage].to_s}) if resource[:allocated_storage]
    props.merge!({"AllowMajorVersionUpgrade" => "false" })
    props.merge!({"AutoMinorVersionUpgrade" => resource[:auto_minor_version_upgrade].to_s}) if resource[:auto_minor_version_upgrade]
    props.merge!({"CharacterSetName" => resource[:character_set_name].to_s}) if resource[:character_set_name]
    props.merge!({"DBInstanceClass" => resource[:db_instance_class]}) if resource[:db_instance_class]
    props.merge!({"Port" => resource[:endpoint][:port].to_s}) if resource[:endpoint] && resource[:endpoint][:port]
    props.merge!({"PubliclyAccessible" => resource[:publicly_accessible].to_s}) if resource[:publicly_accessible]
    props.merge!({"StorageType" => resource[:storage_type].to_s}) if resource[:storage_type]
    props.merge!({"BackupRetentionPeriod" => resource[:backup_retention_period].to_s}) if resource[:backup_retention_period]
    props.merge!({"MasterUsername" => resource[:master_username].to_s}) if resource[:master_username]
    props.merge!({"MasterUserPassword" => "MyPassword"}) if resource[:master_username]
    props.merge!({"PreferredBackupWindow" => resource[:preferred_backup_window].to_s}) if resource[:preferred_backup_window]
    props.merge!({"PreferredMaintenanceWindow" => resource[:preferred_maintenance_window].to_s}) if resource[:preferred_maintenance_window]

    if resource[:storage_type] && resource[:storage_type].eql?("io1")
      props.merge!({"Iops" => resource[:iops].to_s}) if resource[:iops]
    end

    if resource[:read_replica_source_db_instance_identifier]
      props.merge!({"SourceDBInstanceIdentifier" => ref_or_literal(:dbs, resource[:read_replica_source_db_instance_identifier], template, name_mappings)})
      props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone] && !resource[:db_subnet_group]
    else
      props.merge!({"DBName" => "MyDatabase"})
      props.merge!({"Engine" => resource[:engine].to_s}) if resource[:engine]
      props.merge!({"EngineVersion" => resource[:engine_version].to_s}) if resource[:engine_version]
      props.merge!({"LicenseModel" => resource[:license_model]}) if resource[:license_model]

      props.merge!({"MultiAZ" => resource[:multi_az].to_s}) if resource[:multi_az]
      if !resource[:multi_az]
        props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone] && !resource[:db_subnet_group]
      end

      if resource[:db_subnet_group] && resource[:db_subnet_group][:db_subnet_group_name]
        props.merge!({"DBSubnetGroupName" => ref_or_literal(:db_subnet_groups, resource[:db_subnet_group][:db_subnet_group_name], template, name_mappings)})
      end
    end

    if resource[:option_group_memberships]
      resource[:option_group_memberships].each do |og|
        props.merge!({"OptionGroupName" => og[:option_group_name]}) if !og[:option_group_name].starts_with?("default:")
      end
    end

    if resource[:db_parameter_groups]
      resource[:db_parameter_groups].each do |pg|
        props.merge!({"DBParameterGroupName" => ref_or_literal(:db_parameter_groups, pg[:db_parameter_group_name],template, name_mappings)}) if pg[:db_parameter_group_name] && !pg[:db_parameter_group_name].starts_with?("default")
      end
    end

    if resource[:db_security_groups] && !resource[:db_subnet_group]
      groups = []
      resource[:db_security_groups].each do |group|
        groups.push(ref_or_literal(:db_security_groups, group[:db_security_group_name], template, name_mappings))        
      end if resource[:db_security_groups]
      props.merge!({"DBSecurityGroups" => groups}) if !groups.empty?
    end

    if resource[:vpc_security_groups]
      groups = []
      resource[:vpc_security_groups].each do |group|
        groups.push(ref_or_literal(:security_groups, group[:vpc_security_group_id], template, name_mappings))        
      end if resource[:vpc_security_groups]
      props.merge!({"VPCSecurityGroups" => groups}) if !groups.empty?
    end

    tags = []
    if resource[:tag_list]
      resource[:tag_list].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ Databases.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
