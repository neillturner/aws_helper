require 'thor'
require 'awshelper'
require 'awshelper/ec2'
require 'syslog'
require 'net/smtp'
require 'json'

module Awshelper
  class CLI < Thor
    include Thor::Actions

    include Awshelper::Ec2

#def ebs_create(volume_id, snapshot_id, most_recent_snapshot)
#  #TO DO
#  raise "Cannot create a volume with a specific id (EC2 chooses volume ids)" if volume_id
#  if snapshot_id =~ /vol/
#    new_resource.snapshot_id(find_snapshot_id(new_resource.snapshot_id, new_resource.most_recent_snapshot))
#  end
#
#  #nvid = volume_id_in_node_data
#  #if nvid
#  #  # volume id is registered in the node data, so check that the volume in fact exists in EC2
#  #  vol = volume_by_id(nvid)
#  #  exists = vol && vol[:aws_status] != "deleting"
#  #  # TODO: determine whether this should be an error or just cause a new volume to be created. Currently erring on the side of failing loudly
#  #  raise "Volume with id #{nvid} is registered with the node but does not exist in EC2. To clear this error, remove the ['aws']['ebs_volume']['#{new_resource.name}']['volume_id'] entry from this node's data." unless exists
#  #else
#    # Determine if there is a volume that meets the resource's specifications and is attached to the current
#    # instance in case a previous [:create, :attach] run created and attached a volume but for some reason was
#    # not registered in the node data (e.g. an exception is thrown after the attach_volume request was accepted
#    # by EC2, causing the node data to not be stored on the server)
#    if new_resource.device && (attached_volume = currently_attached_volume(instance_id, new_resource.device))
#      Chef::Log.debug("There is already a volume attached at device #{new_resource.device}")
#      compatible = volume_compatible_with_resource_definition?(attached_volume)
#      raise "Volume #{attached_volume[:aws_id]} attached at #{attached_volume[:aws_device]} but does not conform to this resource's specifications" unless compatible
#      Chef::Log.debug("The volume matches the resource's definition, so the volume is assumed to be already created")
#      converge_by("update the node data with volume id: #{attached_volume[:aws_id]}") do
#        node.set['aws']['ebs_volume'][new_resource.name]['volume_id'] = attached_volume[:aws_id]
#        node.save unless Chef::Config[:solo]
#      end
#    else
#      # If not, create volume and register its id in the node data
#      converge_by("create a volume with id=#{new_resource.snapshot_id} size=#{new_resource.size} availability_zone=#{new_resource.availability_zone} and update the node data with created volume's id") do
#      nvid = create_volume(new_resource.snapshot_id,
#                           new_resource.size,
#                           new_resource.availability_zone,
#                           new_resource.timeout,
#                           new_resource.volume_type,
#                           new_resource.piops)
#        node.set['aws']['ebs_volume'][new_resource.name]['volume_id'] = nvid
#        node.save unless Chef::Config[:solo]
#      end
#    end
#  #end
#end

#def ebs_attach(device, volume_id, timeout)
#  # determine_volume returns a Hash, not a Mash, and the keys are
#  # symbols, not strings.
#  vol = determine_volume(device, volume_id)
#  if vol[:aws_status] == "in-use"
#    if vol[:aws_instance_id] != instance_id
#      raise "Volume with id #{vol[:aws_id]} exists but is attached to instance #{vol[:aws_instance_id]}"
#    else
#      Chef::Log.debug("Volume is already attached")
#    end
#  else
#      # attach the volume
#      attach_volume(vol[:aws_id], instance_id, device, timeout)
#  end
#end

#def ebs_detach(device, volume_id, timeout)
#  vol = determine_volume(device, volume_id)
#  detach_volume(vol[:aws_id], timeout)
#end

desc "snap DEVICE [VOLUME_ID]", "Take a snapshot of a EBS Disk."
option :description

long_desc <<-LONGDESC
  'snap DEVICE [VOLUME_ID] --description xxxxxx'
  \x5 Take a snapshot of a EBS Disk by specifying device and/or volume_id.
  \x5 All commands rely on environment variables or the server having an IAM role
    \x5   export AWS_ACCESS_KEY_ID ='xxxxxxxxxx'
    \x5   export AWS_SECRET_ACCESS_KEY ='yyyyyy'
  \x5 For example
    \x5    aws_helper snap /dev/sdf
  \x5 will snap shot the EBS disk attach to device /dev/xvdj
LONGDESC

def snap(device, volume_id=nil)
  vol = determine_volume(device, volume_id)
  snap_description = options[:description] if options[:description]
  snap_description = "Created by aws_helper(#{instance_id}/#{local_ipv4}) for #{ami_id} from #{vol[:aws_id]}" if !options[:description]
  snapshot = ec2.create_snapshot(vol[:aws_id],snap_description)
  log("Created snapshot of #{vol[:aws_id]} as #{snapshot[:aws_id]}")
end

desc "snap_prune DEVICE [VOLUME_ID]", "Prune the number of snapshots."
option :snapshots_to_keep, :type => :numeric, :required => true

long_desc <<-LONGDESC
  'snap_prune DEVICE [VOLUME_ID] --snapshots_to_keep=<numeric>'
  \x5 Prune the number of snapshots of a EBS Disk by specifying device and/or volume_id and the no to keep.
   \x5 All commands rely on environment variables or the server having an IAM role
    \x5    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    \x5    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
  \x5 For example
    \x5    aws_helper snap_prune /dev/sdf --snapshots_to_keep=7
  \x5 will keep the last 7 snapshots of the EBS disk attach to device /dev/xvdj
LONGDESC

def snap_prune(device, volume_id=nil)
  snapshots_to_keep = options[:snapshots_to_keep]
  vol = determine_volume(device, volume_id)
  old_snapshots = Array.new
  log("Checking for old snapshots")
  ec2.describe_snapshots.sort { |a,b| b[:aws_started_at] <=> a[:aws_started_at] }.each do |snapshot|
    if snapshot[:aws_volume_id] == vol[:aws_id]
      log("Found old snapshot #{snapshot[:aws_id]} (#{snapshot[:aws_volume_id]}) #{snapshot[:aws_started_at]}")
      old_snapshots << snapshot
    end
  end
  if old_snapshots.length > snapshots_to_keep
    old_snapshots[snapshots_to_keep, old_snapshots.length].each do |die|
      log("Deleting old snapshot #{die[:aws_id]}")
      ec2.delete_snapshot(die[:aws_id])
    end
  end
end

desc "snap_email TO FROM EMAIL_SERVER", "Email Snapshot List."
option :rows, :type => :numeric, :required => false
option :owner, :type => :numeric, :required => false

long_desc <<-LONGDESC
  'snap_email TO FROM EMAIL_SERVER ['EBS Backups'] --rows=<numeric> --owner=<numeric>'
  \x5 Emails the last 20 snapshots from specific email address via the email_server.
   \x5 All commands rely on environment variables or the server having an IAM role
    \x5    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    \x5    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
  \x5 For example
    \x5    aws_helper snap_email me@mycompany.com ebs.backups@mycompany.com emailserver.com 'My EBS Backups' --rows=20 -owner=999887777
  \x5 will email the list of the latest 20 snapshots to email address me@mycompany.com via email server emailserver.com
  \x5 that belong to aws owner 999887777
LONGDESC

def snap_email(to, from, email_server, subject='EBS Backups')
  rows = 20
  rows = options[:rows] if options[:rows]
  owner = {}
  owner = {:aws_owner => options[:owner]} if options[:owner]
  message = ""
  log("Report on snapshots")
  # ({ Name="start-time", Values="today in YYYY-MM-DD"})
  i = rows
  ec2.describe_snapshots(owner).sort { |a,b| b[:aws_started_at] <=> a[:aws_started_at] }.each do |snapshot|
    if i >0
      message = message+"#{snapshot[:aws_id]} #{snapshot[:aws_volume_id]} #{snapshot[:aws_started_at]} #{snapshot[:aws_description]} #{snapshot[:aws_status]}\n"
      i = i-1
    end
  end
  opts = {}
  opts[:server] = email_server
  opts[:from] = from
  opts[:from_alias] = 'EBS Backups'
  opts[:subject] = subject
  opts[:body] = message
  send_email(to,opts)
end

desc "ebs_cleanup", "Cleanup ebs disks - Delete old server root disks."

long_desc <<-LONGDESC
  'ebs_cleanup'
  \x5 Cleanup ebs disks - Delete old server root disks.
  \x5 Disks that are 8GB in size, not attached to a server, not tagged in any way and from a snapshot.
   \x5 All commands rely on environment variables or the server having an IAM role.
    \x5    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    \x5    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
  \x5 For example
    \x5    ebs_cleanup
LONGDESC

def ebs_cleanup()
 ec2.describe_volumes(:filters => { 'status' => 'available', 'size' => '8' }).each do |r|
   if r[:aws_size] == 8 and  r[:aws_status] == 'available' and r[:tags] == {} and  r[:snapshot_id] != nil and  r[:snapshot_id][0,5] == 'snap-' then
    log("Deleting unused volume #{r[:aws_id]} from snapshot #{r[:snapshot_id]}")
    ec2.delete_volume(r[:aws_id])
   end
 end
end


private

def log(message,type="info")
  # $0 is the current script name
  puts message
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info message } if type == "info"
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info message } if type == "err"
end

# Pulls the volume id from the volume_id attribute or the node data and verifies that the volume actually exists
def determine_volume(device, volume_id)
  vol = currently_attached_volume(instance_id, device)
  vol_id = volume_id || ( vol ? vol[:aws_id] : nil )
  log("volume_id attribute not set and no volume is attached at the device #{device}",'err') unless vol_id
  raise "volume_id attribute not set and no volume is attached at the device #{device}" unless vol_id

  # check that volume exists
  vol = volume_by_id(vol_id)
  log("No volume with id #{vol_id} exists",'err') unless vol
  raise "No volume with id #{vol_id} exists" unless vol

  vol
end


def get_all_instances(filter={})
   data = []
   response = ec2.describe_instances(filter)
   if response.status == 200
     data_s = response.body['reservationSet']
     data_s.each do |rs|
       gs=rs['groupSet']
       rs['instancesSet'].each do |r|
         #r[:aws_instance_id] = r['instanceId']
         #r[:public_ip] = r['ipAddress']
         #r[:aws_state] = r['instanceState']['name']
         #r['groupSet']=rs['groupSet']
         data.push(r)
       end
     end
   end
   data
 end


# Retrieves information for a volume
def volume_by_id(volume_id)
  ec2.describe_volumes.find{|v| v[:aws_id] == volume_id}
end

# Returns the volume that's attached to the instance at the given device or nil if none matches
def currently_attached_volume(instance_id, device)
  ec2.describe_volumes.find{|v| v[:aws_instance_id] == instance_id && v[:aws_device] == device}
end

# Returns true if the given volume meets the resource's attributes
#def volume_compatible_with_resource_definition?(volume)
#  if new_resource.snapshot_id =~ /vol/
#    new_resource.snapshot_id(find_snapshot_id(new_resource.snapshot_id, new_resource.most_recent_snapshot))
#  end
#  (new_resource.size.nil? || new_resource.size == volume[:aws_size]) &&
#  (new_resource.availability_zone.nil? || new_resource.availability_zone == volume[:zone]) &&
#  (new_resource.snapshot_id.nil? || new_resource.snapshot_id == volume[:snapshot_id])
#end

# TODO: support tags in deswcription
#def tag_value(instance,tag_key)
#       options = ec2.describe_tags({:filters => {:resource_id   => instance }} )
# end

# Creates a volume according to specifications and blocks until done (or times out)
def create_volume(snapshot_id, size, availability_zone, timeout, volume_type, piops)
  availability_zone ||= instance_availability_zone

  # Sanity checks so we don't shoot ourselves.
  raise "Invalid volume type: #{volume_type}" unless ['standard', 'io1', 'gp2'].include?(volume_type)

  # PIOPs requested. Must specify an iops param and probably won't be "low".
  if volume_type == 'io1'
    raise 'IOPS value not specified.' unless piops >= 100
  end

  # Shouldn't see non-zero piops param without appropriate type.
  if piops > 0
    raise 'IOPS param without piops volume type.' unless volume_type == 'io1'
  end

  create_volume_opts = { :volume_type => volume_type }
  # TODO: this may have to be casted to a string.  rightaws vs aws doc discrepancy.
  create_volume_opts[:iops] = piops if volume_type == 'io1'

  nv = ec2.create_volume(snapshot_id, size, availability_zone, create_volume_opts)
  Chef::Log.debug("Created new volume #{nv[:aws_id]}#{snapshot_id ? " based on #{snapshot_id}" : ""}")

  # block until created
  begin
    Timeout::timeout(timeout) do
      while true
        vol = volume_by_id(nv[:aws_id])
        if vol && vol[:aws_status] != "deleting"
          if ["in-use", "available"].include?(vol[:aws_status])
            Chef::Log.info("Volume #{nv[:aws_id]} is available")
            break
          else
            Chef::Log.debug("Volume is #{vol[:aws_status]}")
          end
          sleep 3
       else
          raise "Volume #{nv[:aws_id]} no longer exists"
        end
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for volume creation after #{timeout} seconds"
  end

  nv[:aws_id]
end

# Attaches the volume and blocks until done (or times out)
def attach_volume(volume_id, instance_id, device, timeout)
  Chef::Log.debug("Attaching #{volume_id} as #{device}")
  ec2.attach_volume(volume_id, instance_id, device)

  # block until attached
  begin
    Timeout::timeout(timeout) do
      while true
        vol = volume_by_id(volume_id)
        if vol && vol[:aws_status] != "deleting"
          if vol[:aws_attachment_status] == "attached"
            if vol[:aws_instance_id] == instance_id
              Chef::Log.info("Volume #{volume_id} is attached to #{instance_id}")
              break
            else
              raise "Volume is attached to instance #{vol[:aws_instance_id]} instead of #{instance_id}"
            end
          else
            Chef::Log.debug("Volume is #{vol[:aws_status]}")
          end
          sleep 3
        else
          raise "Volume #{volume_id} no longer exists"
        end
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for volume attachment after #{timeout} seconds"
  end
end

# Detaches the volume and blocks until done (or times out)
def detach_volume(volume_id, timeout)
  vol = volume_by_id(volume_id)
  if vol[:aws_instance_id] != instance_id
    Chef::Log.debug("EBS Volume #{volume_id} is not attached to this instance (attached to #{vol[:aws_instance_id]}). Skipping...")
    return
  end
  Chef::Log.debug("Detaching #{volume_id}")
  orig_instance_id = vol[:aws_instance_id]
  ec2.detach_volume(volume_id)

  # block until detached
  begin
    Timeout::timeout(timeout) do
      while true
        vol = volume_by_id(volume_id)
        if vol && vol[:aws_status] != "deleting"
          if vol[:aws_instance_id] != orig_instance_id
            Chef::Log.info("Volume detached from #{orig_instance_id}")
            break
          else
            Chef::Log.debug("Volume: #{vol.inspect}")
          end
        else
          Chef::Log.debug("Volume #{volume_id} no longer exists")
          break
        end
        sleep 3
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for volume detachment after #{timeout} seconds"
  end
end

def send_email(to,opts={})
  opts[:server]      ||= 'localhost'
  opts[:from]        ||= 'email@example.com'
  opts[:from_alias]  ||= 'Example Emailer'
  opts[:subject]     ||= "You need to see this"
  opts[:body]        ||= "Important stuff!"

  msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]}

#{opts[:body]}
END_OF_MESSAGE
   puts "Sending to #{to} from #{opts[:from]} email server #{opts[:server]}"
  Net::SMTP.start(opts[:server]) do |smtp|
    smtp.send_message msg, opts[:from], to
  end
end


end

end


