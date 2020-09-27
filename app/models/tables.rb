class Tables < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the DynamoDB tables we care about
      db = AWS::DynamoDB::Client.new(:region => region, :api_version => '2012-08-10')
      tables = []
      reject_date_times = lambda { |dynamo_attribute|
            if dynamo_attribute[:provisioned_throughput]
              dynamo_attribute[:provisioned_throughput].reject!{ |j| j == :last_increase_date_time}
              dynamo_attribute[:provisioned_throughput].reject!{ |j| j == :last_decrease_date_time}
            end
            } 
      db.list_tables().data[:table_names].each do |tn|
        fixed_table = db.describe_table(:table_name => tn)[:table]
        fixed_table.reject!{ |k| k == :creation_date_time }
        reject_date_times.call(fixed_table)
        if fixed_table[:global_secondary_indexes]
          fixed_table[:global_secondary_indexes].each do |gsi|
            reject_date_times.call(gsi)
          end
        end
        tables << fixed_table
      end
      all_resources.merge!({:tables => tables})
    rescue => e
      all_errors.merge!({:tables => e.message})
      all_resources.merge!({:tables => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "table" + resource[:table_name].tr('^A-Za-z0-9', '') 
  end
  
  def self.OutputList(resource)
    return {"Table Name" => "Name,Ref"}
  end
  
  def initialize(resource)
    @name = Tables.ResourceName(resource)
    super(@name, "AWS::DynamoDB::Table")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    attributes = []
    resource[:attribute_definitions].each do |definition|
      attributes << {"AttributeName" => definition[:attribute_name], "AttributeType" => definition[:attribute_type]} if definition[:attribute_name] && definition[:attribute_type]
    end if resource[:attribute_definitions]
    props.merge!({"AttributeDefinitions" => attributes}) if !attributes.empty?

    key_schema = []
    resource[:key_schema].each do |element|
      key_schema << {"AttributeName" => element[:attribute_name], "KeyType" => element[:key_type]} if element[:attribute_name] && element[:key_type]
    end if resource[:key_schema]
    props.merge!({"KeySchema" => key_schema}) if !key_schema.empty?

    if resource[:provisioned_throughput]
      provisioned_throughput = {}
      provisioned_throughput["ReadCapacityUnits"] = resource[:provisioned_throughput][:read_capacity_units].to_s() if resource[:provisioned_throughput][:read_capacity_units]
      provisioned_throughput["WriteCapacityUnits"] = resource[:provisioned_throughput][:write_capacity_units].to_s() if resource[:provisioned_throughput][:write_capacity_units]
      props.merge!({"ProvisionedThroughput" => provisioned_throughput}) if !provisioned_throughput.empty?
    end

    if resource[:local_secondary_indexes]
      indexes = []
      resource[:local_secondary_indexes].each do |index|
        index_detail = {}
        index_detail["IndexName"] = index[:index_name] if index[:index_name]
        if index[:key_schema]
          key_schema = []
          index[:key_schema].each do |element|
            key_schema << {"AttributeName" => element[:attribute_name], "KeyType" => element[:key_type]} if element[:attribute_name] && element[:key_type]
          end if index[:key_schema]
          index_detail["KeySchema"] = key_schema if !key_schema.empty?
        end
        if index[:projection]
          projection = {}
          projection["ProjectionType"] = index[:projection][:projection_type] if index[:projection][:projection_type]
          projection["NonKeyAttributes"] = index[:projection][:non_key_attributes] if index[:projection][:non_key_attributes]
          index_detail["Projection"] = projection if !projection.empty?
        end
        indexes << index_detail if !index_detail.empty?
      end
      props.merge!({"LocalSecondaryIndexes" => indexes}) if !indexes.empty?
    end
    
    if resource[:global_secondary_indexes]
      indexes = []
      resource[:global_secondary_indexes].each do |index|
        index_detail = {}
        index_detail["IndexName"] = index[:index_name] if index[:index_name]
        if index[:key_schema]
          key_schema = []
          index[:key_schema].each do |element|
            key_schema << {"AttributeName" => element[:attribute_name], "KeyType" => element[:key_type]} if element[:attribute_name] && element[:key_type]
          end if index[:key_schema]
          index_detail["KeySchema"] = key_schema if !key_schema.empty?
        end
        if index[:projection]
          projection = {}
          projection["ProjectionType"] = index[:projection][:projection_type] if index[:projection][:projection_type]
          projection["NonKeyAttributes"] = index[:projection][:non_key_attributes] if index[:projection][:non_key_attributes]
          index_detail["Projection"] = projection if !projection.empty?
        end
        if index[:provisioned_throughput]
          provisioned_throughput = {}
          provisioned_throughput["ReadCapacityUnits"] = index[:provisioned_throughput][:read_capacity_units].to_s() if index[:provisioned_throughput][:read_capacity_units]
          provisioned_throughput["WriteCapacityUnits"] = index[:provisioned_throughput][:write_capacity_units].to_s() if index[:provisioned_throughput][:write_capacity_units]
          index_detail["ProvisionedThroughput"] = provisioned_throughput if !provisioned_throughput.empty?
        end

        indexes << index_detail if !index_detail.empty?
      end
      props.merge!({"GlobalSecondaryIndexes" => indexes}) if !indexes.empty?
    end
    

    return @cf_definition.deep_merge({ Tables.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props}}) 
  end
    
end
