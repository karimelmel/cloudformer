class REDSHIFT_Security_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Redshift security groups we care about
      redshift = AWS::Redshift.new(:region => region)
      all_resources.merge!({:redshift_security_groups => redshift.client.describe_cluster_security_groups().data[:cluster_security_groups]})
    rescue => e
      if region.eql?("us-west-1") || region.eql?("sa-east-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:redshift_security_groups => "Not supported in this region"})
      else
        all_errors.merge!({:redshift_security_groups => e.message})
      end
      all_resources.merge!({:redshift_security_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "rssg" + resource[:cluster_security_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:description]}"
  end  
  
  def self.OutputList(resource)
    return {"Security Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = REDSHIFT_Security_Groups.ResourceName(resource)
    super(@name, "AWS::Redshift::ClusterSecurityGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})
    return @cf_definition.deep_merge({ REDSHIFT_Security_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
