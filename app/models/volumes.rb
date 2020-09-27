class Volumes < CF_converter
  
  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EBS volumes we care about
      ec2 = AWS::EC2.new(:region => region)
      all_volumes = ec2.client.describe_volumes().data[:volume_set]
      # get all instances so we can remove the root devices
      all_instances = []
      all_reservations = ec2.client.describe_instances().data[:reservation_set]
      all_reservations.each do |res|
        all_instances = all_instances + res[:instances_set] if res[:instances_set]
      end
      volumes = []
      if all_volumes
        all_volumes.each do |volume|
          v = volume.clone
          v.reject!{ |k| k == :create_time }
          if v[:attachment_set]
            v[:attachment_set].each do |attach|
              attach.reject!{ |k| k = :attach_time }
            end
          end
          volumes << v
          # Remove any root devices from the list
          if all_instances
            all_instances.each do |instance|
              if instance[:root_device_type] == "ebs"
                bdms = instance[:block_device_mapping]
                if bdms
                  bdms.each do |device|
                    if device[:device_name] == instance[:root_device_name]
                      volumes.delete(v) if device[:ebs] && device[:ebs][:volume_id] == v[:volume_id]
                    end
                  end
                end
              end
            end
          end
        end
      end
      all_resources.merge!({:volumes => volumes})
    rescue => e
      all_errors.merge!({:volumes => e.message})
      all_resources.merge!({:volumes => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "volume" + resource[:volume_id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" "#{tag[:key]}: #{tag[:value]}"
      end
    end          

    return "Availability Zone: #{resource[:availability_zone]} \n" +
           "Size: #{resource[:size]} \n" +
           "Type: #{resource[:volume_type]} \n" +
           "Snapshot Id: #{resource[:snapshot_id]} " + tags
  end
  
  def self.OutputList(resource)
    return {"Volume Id" => "Id,Ref"}
  end

  
  def initialize(resource)
    @name = Volumes.ResourceName(resource)
    super(@name, "AWS::EC2::Volume")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AvailabilityZone" => resource[:availability_zone]}) if resource[:availability_zone]
    props.merge!({"Encrypted" => resource[:encrypted]}) if resource[:encrypted]
    props.merge!({"Iops" => resource[:iops].to_s}) if resource[:iops] && resource[:volume_type] == "io1"
    props.merge!({"Size" => resource[:size].to_s}) if resource[:size]
    props.merge!({"SnapshotId" => resource[:snapshot_id]}) if resource[:snapshot_id]
    props.merge!({"VolumeType" => resource[:volume_type]}) if resource[:volume_type]

    tags = []
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ Volumes.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
