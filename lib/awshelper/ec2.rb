#
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'json'
require 'open-uri'
require 'syslog'
require 'right_aws'


  module Awshelper
    module Ec2
      def find_snapshot_id(volume_id="", find_most_recent=false)
        snapshot_id = nil
        snapshots = if find_most_recent
          ec2.describe_snapshots.sort { |a,b| a[:aws_started_at] <=> b[:aws_started_at] }
        else
          ec2.describe_snapshots.sort { |a,b| b[:aws_started_at] <=> a[:aws_started_at] }
        end
        snapshots.each do |snapshot|
          if snapshot[:aws_volume_id] == volume_id
            snapshot_id = snapshot[:aws_id]
          end
        end
        log("Cannot find snapshot id!",'err') unless snapshot_id
        raise "Cannot find snapshot id!" unless snapshot_id
        log("Snapshot ID is #{snapshot_id}")
        snapshot_id
      end

      def ec2
        @@ec2 ||= create_aws_interface
        #(RightAws::Ec2)
      end

      def instance_id
        @@instance_id ||= query_instance_id
      end

      def ami_id
        @@ami_id ||= query_ami_id
      end

      def local_ipv4
        @@local_ipv4 ||= query_local_ipv4
      end      
 
      def instance_availability_zone
        @@instance_availability_zone ||= query_instance_availability_zone
      end
      
      private

      def create_aws_interface  
      
        region = instance_availability_zone
        region = region[0, region.length-1]
        
        aws_access_key = ENV['AWS_ACCESS_KEY_ID']
        aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']

        if aws_access_key and aws_secret_access_key
          RightAws::Ec2.new(aws_access_key,aws_secret_access_key, {:region => region}) # :logger => Chef::Log,
        else
          log("No env var AWS_ACCESS_KEY_ID and 'AWS_SECRET_ACCESS_KEY so trying role credentials")
          creds = query_role_credentials
          RightAws::Ec2.new(creds['AccessKeyId'], creds['SecretAccessKey'], { :region => region, :token => creds['Token']})
        end
      end

      def query_role
        r = open("http://169.254.169.254/latest/meta-data/iam/security-credentials/",options = {:proxy => false}).readlines.first
        r
      end

      def query_role_credentials(role = query_role)
        log("Instance has no IAM role.",'err') if role.to_s.empty?
        fail "Instance has no IAM role." if role.to_s.empty?
        creds = open("http://169.254.169.254/latest/meta-data/iam/security-credentials/#{role}",options = {:proxy => false}){|f| JSON.parse(f.string)}
        log("Retrieved instance credentials for IAM role #{role}")
        creds
      end

      def query_instance_id
        instance_id = open('http://169.254.169.254/latest/meta-data/instance-id',options = {:proxy => false}){|f| f.gets}
        log("Cannot find instance id!",'err') unless instance_id
        raise "Cannot find instance id!" unless instance_id
        log("Instance ID is #{instance_id}")
        instance_id
      end
      
      def query_ami_id
        ami_id = open('http://169.254.169.254/latest/meta-data/ami-id',options = {:proxy => false}){|f| f.gets}
        log("Cannot find ami id!",'err') unless ami_id
        raise "Cannot find instance id!" unless ami_id
        log("Aim ID is #{ami_id}")
        ami_id
      end 
      
      def query_local_ipv4
        local_ipv4 = open('http://169.254.169.254/latest/meta-data/local-ipv4',options = {:proxy => false}){|f| f.gets}
        log("Cannot find local_ipv4!",'err') unless local_ipv4
        raise "Cannot find local_ipv4!" unless local_ipv4
        log("local_ipv4 is #{local_ipv4}")
        local_ipv4
      end      

      def query_instance_availability_zone
        availability_zone = open('http://169.254.169.254/latest/meta-data/placement/availability-zone/', options = {:proxy => false}){|f| f.gets}
        log("Cannot find availability zone!",'err') unless availability_zone
        raise "Cannot find availability zone!" unless availability_zone
        log("Instance's availability zone is #{availability_zone}")
        availability_zone
      end
      
      def log(message,type="info")
        # $0 is the current script name
        puts message
        Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info message } if type == "info"
        Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info message } if type == "err"
      end
      
      def proxy
         p = ENV['HTTP_PROXY'] if ENV['HTTP_PROXY']
         p
      end   
    end
  end

