# aws_helper

Aws Helper for an instance

Allows functions on EBS volumes, snapshots, IP addresses and more 
* initially snapshots are supported

## Installation

Add this line to your application's Gemfile:

    gem 'aws_helper'
    
And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aws_helper

## Usage

Snapshot EBS attached to device /dev/sdf

    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
    export HTTP_PROXY=http://myproxy:port
    aws_helper snap /dev/sdf --description zzzzzzzzz

Prune so only keep 7 snapshots: 

    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
    aws_helper snap_prune /dev/sdf --snapshots_to_keep=7
    
NOTE: Best Practice is for your server to have an IAM role then you don't
need to specify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
    
Other functions to follow    


