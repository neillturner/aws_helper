require File.join(File.dirname(__FILE__), 'ec2')

  module AwsHelper
    module Elb
      include AwsHelper::Ec2

      def elb
        @@elb ||= create_aws_interface(RightAws::ElbInterface)
      end
    end
  end
end
