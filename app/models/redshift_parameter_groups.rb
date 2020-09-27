class REDSHIFT_Parameter_Groups < CF_converter
  
  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Redshift parameter groups we care about
      redshift = AWS::Redshift.new(:region => region)
      pgs = redshift.client.describe_cluster_parameter_groups().data[:parameter_groups]
      all_pgs = []
      pgs.each do |pg|
        if !pg[:parameter_group_name].starts_with?("default")
          full_pg = pg.clone
          full_params = redshift.client.describe_cluster_parameters(:parameter_group_name => pg[:parameter_group_name]).data[:parameters]
          clean_params = []
          full_params.each do |param|
            clean_params << {"ParameterName" => param[:parameter_name], "ParameterValue" => param[:parameter_value]} if param[:parameter_value] != nil && !param[:parameter_value].eql?("default") && param[:is_modifiable]
          end
          full_pg.merge!({:parameters => clean_params})
          all_pgs << full_pg
        end
      end
      all_resources.merge!({:redshift_parameter_groups => all_pgs})
    rescue => e
      if region.eql?("us-west-1") || region.eql?("sa-east-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:redshift_parameter_groups => "Not supported in this region"})
      else
        all_errors.merge!({:redshift_parameter_groups => e.message})
      end
      all_resources.merge!({:redshift_parameter_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "clupg" + resource[:parameter_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Description: #{resource[:description]}\n " +
           "Family: #{resource[:parameter_group_family]}"
  end  
  
  def self.OutputList(resource)
    return {"Parameter Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = REDSHIFT_Parameter_Groups.ResourceName(resource)
    super(@name, "AWS::Redshift::ClusterParameterGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Description" => resource[:description]})
    props.merge!({"ParameterGroupFamily" => resource[:parameter_group_family]})
    props.merge!({"Parameters" => resource[:parameters]}) if resource[:parameters]

    return @cf_definition.deep_merge({ REDSHIFT_Parameter_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
