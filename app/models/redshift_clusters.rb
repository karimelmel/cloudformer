class REDSHIFT_Clusters < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the RedShift clusters we care about
      redshift = AWS::Redshift.new(:region => region)
      clusters = []
      redshift.client.describe_clusters().data[:clusters].each do |cluster|
        cluster.reject!{ |k| k == :cluster_create_time }
        clusters << cluster
      end
      all_resources.merge!({:redshift_clusters => clusters})
    rescue => e
      if region.eql?("us-west-1") || region.eql?("sa-east-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:redshift_clusters => "Not supported in this region"})
      else
        all_errors.merge!({:redshift_clusters => e.message})
      end
      all_resources.merge!({:redshift_clusters => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "rsclu" + resource[:cluster_identifier].tr('^A-Za-z0-9', '')
  end
    
  def self.get_dependencies(resource, all_resources)
    dbsgResources = []
    if resource[:cluster_security_groups] && !resource[:db_subnet_group]
      resource[:cluster_security_groups].each do |sg|
        all_resources[:redshift_security_groups].each do |all_sg|
          dbsgResources.push(all_sg) if all_sg[:cluster_security_group_name] == sg[:cluster_security_group_name]
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
    if resource[:cluster_subnet_group_name]
      all_resources[:redshift_subnet_groups].each do |all_sg|
        dbsubnetResources.push(all_sg) if all_sg[:cluster_subnet_group_name] == resource[:cluster_subnet_group_name]
      end
    end
    dbpgResources = []
    if resource[:cluster_parameter_groups]
      resource[:cluster_parameter_groups].each do |pg|
        all_resources[:redshift_parameter_groups].each do |all_pg|
          dbpgResources.push(all_pg) if all_pg[:parameter_group_name] == pg[:parameter_group_name]
        end
      end
    end
    return { :security_groups => sgResources, :redshift_security_groups => dbsgResources, :redshift_parameter_groups => dbpgResources, :redshift_subnet_groups => dbsubnetResources}
  end

  def self.get_resource_attributes(resource)
    return "Type: #{resource[:cluster_type]} \n" +
           "Version: #{resource[:cluster_version]} \n" +
           "Database Name: #{resource[:db_name]} \n" +
           "Availability Zone: #{resource[:availability_zone]}"
  end

  def self.OutputList(resource)
    return {"Cluster Name" => "Name,Ref",
            "Endpoint Address" => "Endpoint,GetAtt,Endpoint.Address",
            "Port" => "Port,GetAtt,Endpoint.Port",
            "JDBC Connection String" => "Connect,Join,,jdbc:postgresql://,GetAtt,Endpoint.Address,:,GetAtt,Endpoint.Port,/,MyDatabase"}
  end

  def initialize(resource)
    @name = REDSHIFT_Clusters.ResourceName(resource)
    super(@name, "AWS::Redshift::Cluster")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AllowVersionUpgrade" => resource[:allow_version_upgrade].to_s}) if resource[:allow_version_upgrade]
    props.merge!({"AutomatedSnapshotRetentionPeriod" => resource[:automated_snapshot_retention_period].to_s}) if resource[:automated_snapshot_retention_period]
    props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone] && !resource[:cluster_subnet_group_name]
    props.merge!({"ClusterType" => resource[:number_of_nodes] == 1 ? "single-node" : "multi-node"}) if resource[:number_of_nodes]
    props.merge!({"ClusterVersion" => resource[:cluster_version]}) if resource[:cluster_version]
    props.merge!({"DBName" => resource[:db_name] ? resource[:db_name] : "mydb" })
    props.merge!({"ElasticIp" => resource[:elastic_ip_status][:elastic_ip]}) if resource[:elastic_ip_status] && resource[:elastic_ip_status][:elastic_ip]
    props.merge!({"Encrypted" => resource[:encrypted].to_s}) if resource[:encypted]
    props.merge!({"HsmClientCertificateIdentifier" => resource[:hsm_status][:hsm_client_certificate_identifier]}) if resource[:hsm_status] && resource[:hsm_status][:hsm_client_certificate_identifier]
    props.merge!({"HsmConfigurationIdentifier" => resource[:hsm_status][:hsm_configuration_identifier]}) if resource[:hsm_status] && resource[:hsm_status][:hsm_configuration_identifier]
    props.merge!({"MasterUsername" => resource[:master_username].to_s}) if resource[:master_username]
    props.merge!({"MasterUserPassword" => "MyPassword1"}) if resource[:master_username]
    props.merge!({"NodeType" => resource[:node_type]}) if resource[:node_type]
    props.merge!({"NumberOfNodes" => resource[:number_of_nodes]}) if resource[:number_of_nodes] && resource[:number_of_nodes] > 1
    props.merge!({"Port" => resource[:endpoint][:port].to_s}) if resource[:endpoint] && resource[:endpoint][:port]
    props.merge!({"PubliclyAccessible" => resource[:publicly_accessible].to_s}) if resource[:publicly_accessible]
    props.merge!({"PreferredMaintenanceWindow" => resource[:preferred_maintenance_window].to_s}) if resource[:preferred_maintenance_window]

    if resource[:cluster_subnet_group_name]
      props.merge!({"ClusterSubnetGroupName" =>  ref_or_literal(:redshift_subnet_groups, resource[:cluster_subnet_group_name],template, name_mappings)})
    end

    if resource[:cluster_parameter_groups]
      resource[:cluster_parameter_groups].each do |pg|
        props.merge!({"ClusterParameterGroupName" => ref_or_literal(:redshift_parameter_groups, pg[:parameter_group_name],template, name_mappings)}) if pg[:parameter_group_name] && !pg[:parameter_group_name].starts_with?("default")
      end
    end

    if resource[:cluster_security_groups] && !resource[:cluster_subnet_group_name]
      groups = []
      resource[:cluster_security_groups].each do |group|
        groups.push(ref_or_literal(:redshift_security_groups, group[:cluster_security_group_name], template, name_mappings))        
      end if resource[:cluster_security_groups]
      props.merge!({"ClusterSecurityGroups" => groups}) if !groups.empty?
    end

    if resource[:vpc_security_groups]
      groups = []
      resource[:vpc_security_groups].each do |group|
        groups.push(ref_or_literal(:security_groups, group[:vpc_security_group_id], template, name_mappings))        
      end if resource[:vpc_security_groups]
      props.merge!({"VpcSecurityGroupIds" => groups}) if !groups.empty?
    end

    return @cf_definition.deep_merge({ REDSHIFT_Clusters.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
