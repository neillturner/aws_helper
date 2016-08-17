# aws_helper

[![Gem Version](https://badge.fury.io/rb/aws_helper.svg)](http://badge.fury.io/rb/aws_helper)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/aws_helper?type=total&color=brightgreen)](https://rubygems.org/gems/aws_helper)
[![Build Status](https://travis-ci.org/neillturner/aws_helper.png)](https://travis-ci.org/neillturner/aws_helper)

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

## Minimal Usage

Assuming server start with an IAM role that have read access to AWS can create and delete snapshots: 

Snapshot EBS root device at /dev/sda1

    aws_helper snap /dev/sda1 --description zzzzzzzzz

Prune so only keep 7 snapshots: 

    aws_helper snap_prune /dev/sda1 --snapshots_to_keep=7

Email me a list of the latest 20 snapshots:

    aws_helper snap_email me@company.com ebs.backups@company.com mysmtpemailserver.com

Cleanup ebs disks - Delete old server root disks:

    aws_helper ebs_cleanup

    Disks that are 8GB in size, not attached to a server, not tagged in any way and from a snapshot will be deleted.     

## Complex Usage

If your server does not have a role then you need to code the AWS keys which is not best practice:

Snapshot EBS attached to device /dev/sdf volume vol-123456 access AWS through an http proxy: 

    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
    export HTTP_PROXY=http://myproxy:port
    aws_helper snap /dev/sdf vol-123456 --description zzzzzzzzz

Prune so only keep 20 snapshots: 

    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
    export HTTP_PROXY=http://myproxy:port
    aws_helper snap_prune /dev/sdf vol-123456 --snapshots_to_keep=20

Email me a list of the latest 30 snapshots with a subject title on email:

    export AWS_ACCESS_KEY_ID ='xxxxxxxxxxxx'
    export AWS_SECRET_ACCESS_KEY ='yyyyyyyy'
    export HTTP_PROXY=http://myproxy:port
    aws_helper snap_email me@company.com ebs.backups@company.com mysmtpemailserver.com 'My EBS Backups' --rows=30
 
Other functions to follow     


