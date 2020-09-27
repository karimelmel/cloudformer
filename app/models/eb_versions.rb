class EB_Versions < CF_converter
  
  attr_accessor :name
  @@resource_index = 0
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EB Versions
      eb = AWS::ElasticBeanstalk.new(:region => region)
      versions = []
      eb.client.describe_application_versions().data[:application_versions].each do |version|
        full_version = version.clone
        full_version.reject!{ |k| k == :date_created }
        full_version.reject!{ |k| k == :date_updated }
        full_version[:name] = "version#{version[:version_label].tr('^A-Za-z0-9', '')}#{@@resource_index}"
        @@resource_index = @@resource_index + 1
        versions << full_version
      end
      all_resources.merge!({:eb_versions => versions})
    rescue => e
      if region.eql?("us-gov-west-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:eb_versions => "Not supported in this region"})
      else
        all_errors.merge!({:eb_versions => e.message})
      end
      all_resources.merge!({:eb_versions => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:name]
  end
  
  def self.get_resource_attributes(resource)
    return "Application Name: #{resource[:application_name]} \n" +
           "Description: #{resource[:description]}" +
           "Version Label: #{resource[:version_label]}"
  end

  def self.OutputList(resource)
    return {"Version Label" => "Name,Ref"}
  end

  def initialize(resource)
    @name = EB_Versions.ResourceName(resource)
    super(@name, "AWS::ElasticBeanstalk::ApplicationVersion")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"ApplicationName" => ref_or_literal(:eb_applications, resource[:application_name], template, name_mappings)}) if resource[:application_name]
    props.merge!({"Description" => resource[:description]}) if resource[:description]

    source_bundle = {}
    if resource[:source_bundle]
      source_bundle["S3Bucket"] = resource[:source_bundle][:s3_bucket] if resource[:source_bundle][:s3_bucket] 
      source_bundle["S3Key"] = resource[:source_bundle][:s3_key] if resource[:source_bundle][:s3_key]
    end
    props.merge!({"SourceBundle" => source_bundle}) if !source_bundle.empty?

    return @cf_definition.deep_merge({ EB_Versions.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
